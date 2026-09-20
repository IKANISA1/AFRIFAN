"""Commerce cases for the existing disposable database/lock-observed runner."""
import json


def run_commerce_concurrency(sql, operations_after_lock, root):
    def cid(n): return '99750000-0000-4000-8000-'+str(n).zfill(12)
    def call(kind, numbers, ref=None, amount=1000, actor=1):
        ref=ref or 'RS-'+kind.upper()+'-QA-'+str(numbers[0])
        return "set role service_role; select public.confirm_club_commerce_payment('%s',array[%s]::uuid[],'%s','%s',%d,9975001,'%s','mtn_rwanda','250788111222','RWF','RW','%s');" % (kind,','.join("'%s'"%cid(n) for n in numbers),cid(actor),ref,amount,cid(100),cid(numbers[0]+2000))
    def decisions(responses):
        assert all(r.returncode==0 for r in responses),[r.stderr for r in responses]
        return [json.loads(r.stdout.strip().splitlines()[-1]) for r in responses]
    def counts():
        return json.loads(sql("select jsonb_build_object('posted',(select count(*) from public.momo_ledger_entries where club_id=9975001 and ledger_status='posted'),'matched',(select count(*) from public.momo_reconciliations where club_id=9975001 and match_status='matched'),'points',(select sum(points) from public.fan_memberships where partner_id='%s'));"%cid(100)).stdout.strip())
    rows=[]
    assert sql('select count(*) from public.african_football_clubs where id=9975001;').stdout.strip()=='0'
    seed=(root/'supabase/tests/commerce_confirmation_atomic_contract.sql').read_text().split('-- Helper uses caller privileges')[0]
    sql(seed+'\ncommit;')
    ds=decisions(operations_after_lock("select id from public.tickets where id='%s' for update;"%cid(501),[call('ticket',[501,502],amount=2000)]*5))
    assert all(x['status']=='confirmed' for x in ds) and sum(x['newly_confirmed'] for x in ds)==1,ds
    assert counts()=={'posted':1,'matched':1,'points':100},counts()
    rows.append({'case':'five overlapping ticket confirmations','status':'pass','persisted':counts()})

    ds=decisions(operations_after_lock("select id from public.tickets where id='%s' for update;"%cid(504),[call('ticket',[504])],before_commit="update public.tickets set status='cancelled' where id='%s';"%cid(504)))
    assert ds[0]['status']=='manual_review' and counts()['posted']==1,ds
    rows.append({'case':'ticket cancellation wins while confirmation waits','status':'pass'})

    ds=decisions(operations_after_lock("select id from public.pending_transactions where reference='RS-SHOP-QA-601' for update;",[call('shop',[601])],before_commit="update public.pending_transactions set recipient_momo='250788999999' where reference='RS-SHOP-QA-601';"))
    assert ds[0]['status']=='manual_review' and counts()['posted']==1,ds
    rows.append({'case':'receiver change wins while confirmation waits','status':'pass'})
    sql("update public.pending_transactions set recipient_momo='250788111222' where reference='RS-SHOP-QA-601';")

    sql("update public.shop_orders set inventory_reserved=true,reservation_expires_at=clock_timestamp()+interval '1 second' where id='%s';"%cid(603))
    ds=decisions(operations_after_lock("select id from public.shop_orders where id='%s' for update;"%cid(603),[call('shop',[603])],before_commit='select pg_sleep(1.2);'))
    assert ds[0]['status']=='manual_review' and counts()['posted']==1,ds
    rows.append({'case':'reservation expiry rechecked after row wait','status':'pass'})
    sql("update public.shop_orders set inventory_reserved=false,reservation_expires_at=null where id='%s';"%cid(603))

    sql("update public.shop_orders set status='pending' where id='%s';"%cid(605))
    ds=decisions(operations_after_lock("select id from public.shop_orders where id='%s' for update;"%cid(605),[call('shop',[605])],before_commit="update public.shop_orders set status='cancelled' where id='%s';"%cid(605)))
    assert ds[0]['status']=='manual_review' and counts()['posted']==1,ds
    rows.append({'case':'shop cancellation wins while confirmation waits','status':'pass'})

    sql("insert into auth.users(id,aud,role,is_anonymous) values('%s','authenticated','authenticated',false); insert into public.users(id,phone,full_name) values('%s','+250799750002','Commerce second QA'); insert into public.profiles(id,club_id) values('%s',9975001);"%(cid(2),cid(2),cid(2)))
    sql("update public.shop_orders set user_id='%s' where id='%s'; update public.pending_transactions set user_id='%s' where reference='RS-SHOP-QA-603'; update public.momo_sms_raw set user_id='%s' where id='%s'; update public.momo_sms_parsed set user_id='%s' where id='%s';"%(cid(2),cid(603),cid(2),cid(2),cid(1603),cid(2),cid(2603)))
    sql("update public.momo_sms_parsed set momo_tx_id='DUP-COMMERCE-TRANSACTION' where id in ('%s','%s');"%(cid(2601),cid(2603)))
    ds=decisions(operations_after_lock("select pg_advisory_xact_lock(hashtextextended('momo-allocation:mtn_rwanda:DUP-COMMERCE-TRANSACTION',0));",[call('shop',[601]),call('shop',[603],actor=2)]))
    assert sorted(x['status'] for x in ds)==['confirmed','manual_review'],ds
    assert counts()=={'posted':2,'matched':2,'points':110},counts()
    rows.append({'case':'two checkouts cannot reuse one provider transaction','status':'pass','persisted':counts()})

    # A dropped response after commit must be recoverable without another debit
    # or points award even if an operator has subsequently changed the payee.
    winner=601 if ds[0]['status']=='confirmed' else 603
    sql("update public.pending_transactions set recipient_momo='250788000000' where reference='RS-SHOP-QA-%d';"%winner)
    replay=decisions([sql(call('shop',[winner],actor=1 if winner==601 else 2),check=False)])[0]
    assert replay['status']=='confirmed' and replay['newly_confirmed'] is False,replay
    assert counts()=={'posted':2,'matched':2,'points':110},counts()
    rows.append({'case':'committed receipt recovers after response loss without replaying side effects','status':'pass','persisted':counts()})
    for row in rows:
        print('PASS commerce', row['case'], flush=True)
    return rows
