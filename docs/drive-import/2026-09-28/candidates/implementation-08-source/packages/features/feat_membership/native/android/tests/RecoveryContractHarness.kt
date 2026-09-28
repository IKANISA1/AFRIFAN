package com.africlub.recovery

import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardOpenOption.READ
import java.nio.channels.FileChannel
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import javax.crypto.SecretKey
import javax.crypto.spec.SecretKeySpec

private const val APP="com.africlub.synthetic"
private const val USER="20000000-0000-4000-8000-000000000001"
private const val SCOPE="africlub-membership-v1:24:$USER"
private const val OTHER="africlub-payment-handoff-v1:24:$USER"
private fun id()=UUID.randomUUID().toString()
private val testKey=SecretKeySpec(ByteArray(32){(it+7).toByte()},"AES")
private val sync=DirectorySync{FileChannel.open(it,READ).use{c->c.force(true)}}
private class Keys(var key:SecretKey?=null):RecoveryKeySource {
 var creations=0
 override fun existing()=key
 override fun create():SecretKey {creations++;check(key==null);key=testKey;return key!!}
}
private class Fixture(val root:Path=Files.createTempDirectory("africlub-recovery-test-").toRealPath()) : AutoCloseable {
 val keys=Keys();val owner=id();var req=id();val store=RecoveryStore(root,APP,keys,sync)
 fun acquire(scope:String=SCOPE)=store.tryAcquire(owner,scope,req)!!
 fun release(scope:String=SCOPE){store.release(owner,scope,req);req=id()}
 override fun close(){store.closeOwner(owner);root.toFile().deleteRecursively()}
}
private fun failure(expected:String?=null,work:()->Unit) {
 try{work()}catch(e:RecoveryFailure){if(expected!=null)check(e.code==expected){"Expected $expected; got ${e.code}"};return}
 error("Expected refusal")
}
private var passed=0
private fun test(name:String,work:()->Unit){try{work();passed++;println("PASS $name")}catch(e:Throwable){System.err.println("FAIL $name: ${e.javaClass.simpleName}: ${e.message}");throw e}}
private fun child(mode:String,root:Path):Process {
 val java=Path.of(System.getProperty("java.home"),"bin","java").toString()
 return ProcessBuilder(java,"-cp",System.getProperty("java.class.path"),"com.africlub.recovery.RecoveryContractHarnessKt",mode,root.toString()).redirectErrorStream(true).start()
}
private fun childMain(mode:String,root:Path) {
 val store=RecoveryStore(root,APP,Keys(testKey),sync);val owner=id();val req=id()
 fun acquire():String {val deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(15)
  while(System.nanoTime()<deadline){val token=store.tryAcquire(owner,SCOPE,req);if(token!=null)return token;Thread.sleep(2)};error("lock timeout")}
 when(mode) {
  "probe" -> {val token=store.tryAcquire(owner,SCOPE,req);println(if(token==null)"BUSY" else "ACQUIRED");store.closeOwner(owner)}
  "increment" -> repeat(15){val token=acquire();val old=store.load(owner,SCOPE,token);check(store.compareAndSet(owner,SCOPE,token,old,((old?.toInt()?:0)+1).toString()));store.release(owner,SCOPE,req)}
  "reserve-and-wait" -> {val token=acquire();val old=store.load(owner,SCOPE,token);check(store.compareAndSet(owner,SCOPE,token,old,"{\"phase\":\"reserved\"}"));println("RESERVED");System.out.flush();Thread.sleep(60000)}
 }
}
fun main(args:Array<String>) {
 if(args.isNotEmpty()){childMain(args[0],Path.of(args[1]));return}
 test("empty first initialization and exactly one key creation"){Fixture().use{f->val t=f.acquire();check(f.store.load(f.owner,SCOPE,t)==null);check(f.keys.creations==1)}}
 test("durable write and reopen with same key"){Fixture().use{f->val t=f.acquire();check(f.store.compareAndSet(f.owner,SCOPE,t,null,"pending"));f.release();val second=RecoveryStore(f.root,APP,f.keys,sync);val token=second.tryAcquire(f.owner,SCOPE,f.req)!!;check(second.load(f.owner,SCOPE,token)=="pending");second.closeOwner(f.owner)}}
 test("compare-and-set mismatch cannot overwrite"){Fixture().use{f->val t=f.acquire();check(f.store.compareAndSet(f.owner,SCOPE,t,null,"first"));check(!f.store.compareAndSet(f.owner,SCOPE,t,null,"second"));check(f.store.load(f.owner,SCOPE,t)=="first")}}
 test("matching value is an idempotent byte-preserving write"){Fixture().use{f->val t=f.acquire();f.store.compareAndSet(f.owner,SCOPE,t,null,"a");val before=Files.readAllBytes(f.root.resolve("recovery.v1"));check(f.store.compareAndSet(f.owner,SCOPE,t,"a","a"));check(before.contentEquals(Files.readAllBytes(f.root.resolve("recovery.v1"))))}}
 test("new ciphertext IV for changed values"){Fixture().use{f->val t=f.acquire();f.store.compareAndSet(f.owner,SCOPE,t,null,"a");val a=Files.readAllBytes(f.root.resolve("recovery.v1"));f.store.compareAndSet(f.owner,SCOPE,t,"a","b");f.store.compareAndSet(f.owner,SCOPE,t,"b","a");check(!a.copyOfRange(8,20).contentEquals(Files.readAllBytes(f.root.resolve("recovery.v1")).copyOfRange(8,20)))}}
 test("no raw user or marker in stored file"){Fixture().use{f->val t=f.acquire();f.store.compareAndSet(f.owner,SCOPE,t,null,"PRIVATE-CHECKOUT-MARKER");val text=Files.readAllBytes(f.root.resolve("recovery.v1")).toString(Charsets.ISO_8859_1);check(!text.contains(USER)&&!text.contains("PRIVATE-CHECKOUT-MARKER"));check(Files.list(f.root).use{s->s.noneMatch{it.fileName.toString().contains(USER)}})}}
 test("account and operation scopes remain distinct"){Fixture().use{f->val t=f.acquire();f.store.compareAndSet(f.owner,SCOPE,t,null,"checkout");f.release();val t2=f.acquire(OTHER);check(f.store.load(f.owner,OTHER,t2)==null);f.store.compareAndSet(f.owner,OTHER,t2,null,"handoff");f.release(OTHER);val t3=f.acquire();check(f.store.load(f.owner,SCOPE,t3)=="checkout")}}
 test("same acquisition recovers same token after lost reply"){Fixture().use{f->val t=f.acquire();check(f.store.tryAcquire(f.owner,SCOPE,f.req)==t)}}
 test("new acquisition request cannot enter held critical section"){Fixture().use{f->f.acquire();check(f.store.tryAcquire(f.owner,SCOPE,id())==null)}}
 test("other engine cannot enter held critical section"){Fixture().use{f->f.acquire();val s=RecoveryStore(f.root,APP,f.keys,sync);check(s.tryAcquire(id(),SCOPE,id())==null)}}
 test("global installation lock also serializes different scopes"){Fixture().use{f->f.acquire();check(f.store.tryAcquire(id(),OTHER,id())==null)}}
 test("wrong owner cannot read"){Fixture().use{f->val t=f.acquire();failure("recovery_lock_required"){f.store.load(id(),SCOPE,t)}}}
 test("wrong token cannot write"){Fixture().use{f->f.acquire();failure("recovery_lock_required"){f.store.compareAndSet(f.owner,SCOPE,id(),null,"bad")}}}
 test("wrong scope cannot reuse lease"){Fixture().use{f->val t=f.acquire();failure("recovery_lock_required"){f.store.load(f.owner,OTHER,t)}}}
 test("wrong acquisition cannot release another operation"){Fixture().use{f->val t=f.acquire();f.store.release(f.owner,SCOPE,id());check(f.store.load(f.owner,SCOPE,t)==null)}}
 test("late release cannot unlock newer critical section"){Fixture().use{f->f.acquire();val old=f.req;f.release();val t=f.acquire();f.store.release(f.owner,SCOPE,old);check(f.store.load(f.owner,SCOPE,t)==null)}}
 test("released token cannot read or write"){Fixture().use{f->val t=f.acquire();f.release();failure("recovery_lock_required"){f.store.load(f.owner,SCOPE,t)}}}
 test("engine detach closes only its own lease"){Fixture().use{f->val t=f.acquire();f.store.closeOwner(id());check(f.store.load(f.owner,SCOPE,t)==null);f.store.closeOwner(f.owner);check(f.store.tryAcquire(f.owner,SCOPE,id())!=null)}}
 test("lease can be released on a different executor thread"){Fixture().use{f->f.acquire();val th=Thread{f.store.release(f.owner,SCOPE,f.req)};th.start();th.join();check(f.store.tryAcquire(f.owner,SCOPE,id())!=null)}}
 for(bad in listOf("","../../secret","africlub-membership-v1:0:$USER","africlub-membership-v1:24:not-a-uuid","africlub-membership-v1:24:$USER\n","africlub-other-v1:24:$USER"))test("reject malformed scope ${bad.take(25)}"){Fixture().use{f->failure{f.store.tryAcquire(f.owner,bad,f.req)}}}
 test("reject empty and oversized values"){Fixture().use{f->val t=f.acquire();failure{f.store.compareAndSet(f.owner,SCOPE,t,null,"")};failure{f.store.compareAndSet(f.owner,SCOPE,t,null,"x".repeat(2049))}}}
 test("UTF-8 byte bound not only character count"){Fixture().use{f->val t=f.acquire();check(f.store.compareAndSet(f.owner,SCOPE,t,null,"é".repeat(1024)));failure{f.store.compareAndSet(f.owner,SCOPE,t,"é".repeat(1024),"é".repeat(1025))}}}
 test("unpaired surrogate refused before mutation"){Fixture().use{f->val t=f.acquire();failure{f.store.compareAndSet(f.owner,SCOPE,t,null,"\uD800")}}}
 for(position in listOf(0,8,20,-1))test("corruption byte $position is not empty recovery"){Fixture().use{f->val t=f.acquire();f.store.compareAndSet(f.owner,SCOPE,t,null,"pending");val p=f.root.resolve("recovery.v1");val bytes=Files.readAllBytes(p);val n=if(position<0)bytes.lastIndex else position;bytes[n]=(bytes[n].toInt() xor 1).toByte();Files.write(p,bytes);failure("recovery_corrupt"){f.store.load(f.owner,SCOPE,t)};check(Files.readAllBytes(p).contentEquals(bytes))}}
 test("truncated ciphertext refused"){Fixture().use{f->val t=f.acquire();Files.write(f.root.resolve("recovery.v1"),ByteArray(20));failure("recovery_corrupt"){f.store.load(f.owner,SCOPE,t)}}}
 test("different encryption key refused without reset"){Fixture().use{f->val t=f.acquire();f.keys.key=SecretKeySpec(ByteArray(32){99},"AES");failure("recovery_corrupt"){f.store.load(f.owner,SCOPE,t)};check(f.keys.creations==1)}}
 test("missing encryption key refused without recreation"){Fixture().use{f->f.acquire();f.release();f.keys.key=null;failure("recovery_key_unavailable"){f.acquire()};check(f.keys.creations==1)}}
 test("missing ciphertext with existing key refused"){Fixture().use{f->f.acquire();f.release();Files.delete(f.root.resolve("recovery.v1"));failure("recovery_state_missing"){f.acquire()};check(f.keys.creations==1)}}
 test("different application AAD cannot decrypt"){Fixture().use{f->f.acquire();f.release();val s=RecoveryStore(f.root,"com.africlub.other",f.keys,sync);failure("recovery_corrupt"){s.tryAcquire(f.owner,SCOPE,f.req)}}}
 test("leftover pending file prevents empty reinitialization"){Fixture().use{f->Files.write(f.root.resolve("recovery.pending"),byteArrayOf(1));failure("recovery_state_missing"){f.acquire()};check(f.keys.creations==0)}}
 for(stage in listOf("after_file_sync","after_rename","after_directory_sync"))test("write fault $stage retains safe known or unknown state"){Fixture().use{f->var t=f.acquire();f.store.compareAndSet(f.owner,SCOPE,t,null,"old");f.release();val s=RecoveryStore(f.root,APP,f.keys,sync){if(it==stage)throw java.io.IOException("SYNTHETIC")};t=s.tryAcquire(f.owner,SCOPE,f.req)!!;failure("recovery_write_unknown"){s.compareAndSet(f.owner,SCOPE,t,"old","reserved")};check(s.load(f.owner,SCOPE,t)==if(stage=="after_file_sync")"old" else "reserved");s.closeOwner(f.owner)}}
 test("directory fsync failure is unknown not successful CAS"){Fixture().use{f->var t=f.acquire();f.store.compareAndSet(f.owner,SCOPE,t,null,"old");f.release();val s=RecoveryStore(f.root,APP,f.keys,DirectorySync{throw java.io.IOException("SYNTHETIC")});t=s.tryAcquire(f.owner,SCOPE,f.req)!!;failure("recovery_write_unknown"){s.compareAndSet(f.owner,SCOPE,t,"old","reserved")};check(s.load(f.owner,SCOPE,t)=="reserved");s.closeOwner(f.owner)}}
 test("scope capacity refuses eviction of old recovery records"){Fixture().use{f->repeat(64){n->val scope="africlub-membership-v1:${n+1}:$USER";val t=f.acquire(scope);check(f.store.compareAndSet(f.owner,scope,t,null,"pending"));f.release(scope)};val scope="africlub-membership-v1:65:$USER";val t=f.acquire(scope);failure("recovery_capacity"){f.store.compareAndSet(f.owner,scope,t,null,"pending")};check(f.store.load(f.owner,scope,t)==null)}}
 test("plaintext codec rejects trailing bytes"){val b=SnapshotCodec.encode(Snapshot(0,emptyMap()));failure("recovery_corrupt"){SnapshotCodec.decode(b+byteArrayOf(1))}}
 test("plaintext codec rejects unsupported version"){val b=SnapshotCodec.encode(Snapshot(0,emptyMap()));b[3]=2;failure("recovery_corrupt"){SnapshotCodec.decode(b)}}
 test("symlink lock rejected"){Fixture().use{f->val other=Files.createTempFile("africlub-other-",".tmp");try{Files.createSymbolicLink(f.root.resolve("recovery.lock"),other);failure{f.acquire()}}finally{Files.deleteIfExists(other)}}}
 test("symlink state rejected without reading target"){Fixture().use{f->f.acquire();f.release();Files.delete(f.root.resolve("recovery.v1"));val other=Files.createTempFile("africlub-other-",".tmp");try{Files.createSymbolicLink(f.root.resolve("recovery.v1"),other);failure("recovery_corrupt"){f.acquire()}}finally{Files.deleteIfExists(other)}}}
 test("symlink root rejected"){Fixture().use{f->val alias=f.root.parent.resolve(id());try{Files.createSymbolicLink(alias,f.root);failure{RecoveryStore(alias,APP,f.keys,sync)}}finally{Files.deleteIfExists(alias)}}}
 test("separate process cannot acquire held lock"){Fixture().use{f->f.acquire();val p=child("probe",f.root);check(p.waitFor(10,TimeUnit.SECONDS));check(p.inputStream.bufferedReader().readText().trim()=="BUSY")}}
 test("four JVM processes serialize 60 durable increments"){Fixture().use{f->f.acquire();f.release();val children=List(4){child("increment",f.root)};for(p in children){check(p.waitFor(20,TimeUnit.SECONDS));check(p.exitValue()==0){p.inputStream.bufferedReader().readText()}};val t=f.acquire();check(f.store.load(f.owner,SCOPE,t)=="60")}}
 test("eight threads and store instances serialize 80 CAS effects"){Fixture().use{f->f.acquire();f.release();val pool=Executors.newFixedThreadPool(8);val done=CountDownLatch(8);val errors=java.util.concurrent.ConcurrentLinkedQueue<Throwable>()
 repeat(8){pool.execute{val s=RecoveryStore(f.root,APP,f.keys,sync);val owner=id();try{repeat(10){val req=id();var token:String?=null;val end=System.nanoTime()+TimeUnit.SECONDS.toNanos(15);while(token==null&&System.nanoTime()<end){token=s.tryAcquire(owner,SCOPE,req);if(token==null)Thread.sleep(1)};check(token!=null);val old=s.load(owner,SCOPE,token);check(s.compareAndSet(owner,SCOPE,token,old,((old?.toInt()?:0)+1).toString()));s.release(owner,SCOPE,req)}}catch(e:Throwable){errors.add(e)}finally{s.closeOwner(owner);done.countDown()}}}
 check(done.await(20,TimeUnit.SECONDS));pool.shutdownNow();check(errors.isEmpty()){errors.toString()};val t=f.acquire();check(f.store.load(f.owner,SCOPE,t)=="80")}}
 test("process death releases lock but retains reserved handoff"){Fixture().use{f->f.acquire();f.release();val p=child("reserve-and-wait",f.root);try{val lines=Executors.newSingleThreadExecutor();try{check(lines.submit<String>{p.inputStream.bufferedReader().readLine()}.get(10,TimeUnit.SECONDS)=="RESERVED")}finally{lines.shutdownNow()};check(f.store.tryAcquire(f.owner,SCOPE,f.req)==null);p.destroyForcibly();check(p.waitFor(10,TimeUnit.SECONDS));val t=f.acquire();check(f.store.load(f.owner,SCOPE,t)=="{\"phase\":\"reserved\"}")}finally{p.destroyForcibly()}}}

 test("dispatcher disabled does not initialize any file"){Fixture().use{f->var calls=0;val d=RecoveryDispatcher(false,{calls++;f.store});failure("recovery_disabled"){d.invoke("tryAcquire",mapOf("scope" to SCOPE,"acquisitionId" to id()))};check(calls==0&&!Files.exists(f.root.resolve("recovery.v1")))}}
 test("dispatcher end-to-end CAS contract"){Fixture().use{f->val d=RecoveryDispatcher(true,{f.store});val key=id();val lease=d.invoke("tryAcquire",mapOf("scope" to SCOPE,"acquisitionId" to key));check(lease["busy"]==false&&lease["version"]==1);val params=mapOf("scope" to SCOPE,"lease" to lease["lease"]);check(d.invoke("load",params)["value"]==null);check(d.invoke("compareAndSet",params+mapOf("expected" to null,"value" to "pending"))["updated"]==true);check(d.invoke("load",params)["value"]=="pending");d.invoke("release",mapOf("scope" to SCOPE,"acquisitionId" to key));d.close()}}
 for(extra in listOf("path","owner","keyAlias","secret","root"))test("dispatcher refuses supplied $extra"){Fixture().use{f->var calls=0;val d=RecoveryDispatcher(true,{calls++;f.store});failure{d.invoke("tryAcquire",mapOf("scope" to SCOPE,"acquisitionId" to id(),extra to "untrusted"))};check(calls==0)}}
 for(method in listOf("clear","delete","reset","rotateKey","dial","pay"))test("dispatcher rejects unsupported $method"){Fixture().use{_->val d=RecoveryDispatcher(true,{error("should not initialize")});failure{d.invoke(method,emptyMap<String,String>())}}}
 test("dispatcher fails closed on locked device"){Fixture().use{_->val d=RecoveryDispatcher(true,{error("should not initialize")},{throw RecoveryFailure("recovery_device_locked")});failure("recovery_device_locked"){d.invoke("tryAcquire",mapOf("scope" to SCOPE,"acquisitionId" to id()))}}}
 test("dispatcher release still works after device lock"){Fixture().use{f->var locked=false;val d=RecoveryDispatcher(true,{f.store},{if(locked)throw RecoveryFailure("recovery_device_locked")});val req=id();d.invoke("tryAcquire",mapOf("scope" to SCOPE,"acquisitionId" to req));locked=true;d.invoke("release",mapOf("scope" to SCOPE,"acquisitionId" to req));check(f.store.tryAcquire(f.owner,SCOPE,f.req)!=null);d.close()}}
 test("dispatcher close prevents late calls and releases engine lock"){Fixture().use{f->val d=RecoveryDispatcher(true,{f.store});d.invoke("tryAcquire",mapOf("scope" to SCOPE,"acquisitionId" to id()));d.close();failure("recovery_disabled"){d.invoke("load",emptyMap<String,String>())};check(f.store.tryAcquire(f.owner,SCOPE,f.req)!=null)}}
 test("dispatcher oversized value refused before native access"){Fixture().use{f->var calls=0;val d=RecoveryDispatcher(true,{calls++;f.store});failure{d.invoke("compareAndSet",mapOf("scope" to SCOPE,"lease" to id(),"expected" to null,"value" to "x".repeat(2049)))};check(calls==0)}}
 println("SUMMARY passed=$passed failed=0 skipped=0")
}
