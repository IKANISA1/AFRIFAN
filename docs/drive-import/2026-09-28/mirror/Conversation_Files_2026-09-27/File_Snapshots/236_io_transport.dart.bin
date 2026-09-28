import 'dart:convert';
import 'dart:io';
import 'ports.dart';
import 'models.dart';

/// Dedicated client per operation: no shared cookie jar, no implicit write retry.
/// Uses normal TLS trust and proxy configuration; never accepts bad certificates.
final class IoMembershipTransport implements NativeMembershipTransport {
  const IoMembershipTransport();
  @override
  Future<NativeWireResponse> send(NativeWireRequest request,Duration timeout) async {
    requireContract(request.uri.scheme=='https'&&request.uri.userInfo.isEmpty&&['GET','POST'].contains(request.method),'invalid_transport');
    requireContract(timeout.inMilliseconds>0&&timeout.inMilliseconds<=30000,'invalid_transport');
    final client=HttpClient()..connectionTimeout=timeout..autoUncompress=false;
    HttpClientRequest? active;
    bool stopped=false;
    Future<NativeWireResponse> run() async {
      final outgoing=await client.openUrl(request.method,request.uri);
      active=outgoing;
      if(stopped){outgoing.abort();throw const NativeMembershipException('transport_cancelled');}
      outgoing.followRedirects=false;
      outgoing.maxRedirects=0;
      outgoing.persistentConnection=false;
      outgoing.headers.set(HttpHeaders.acceptEncodingHeader,'identity');
      outgoing.headers.set(HttpHeaders.acceptHeader,'application/json');
      request.headers.forEach((key,value)=>outgoing.headers.set(key,value));
      if(request.body!=null){final bytes=utf8.encode(request.body!);requireContract(bytes.length<=2048,'payload_too_large');outgoing.add(bytes);}
      final response=await outgoing.close();
      requireContract(response.contentLength<=16384,'response_too_large');
      final encoding=response.headers.value(HttpHeaders.contentEncodingHeader);
      requireContract(encoding==null||encoding=='identity','unsupported_response_encoding');
      final bytes=<int>[];
      await for(final chunk in response){requireContract(bytes.length+chunk.length<=16384,'response_too_large');bytes.addAll(chunk);}
      final headers=<String,String>{};response.headers.forEach((key,values)=>headers[key.toLowerCase()]=values.join(','));
      return NativeWireResponse(response.statusCode,headers,utf8.decode(bytes,allowMalformed:false));
    }
    try {return await run().timeout(timeout);}
    finally {stopped=true;active?.abort();client.close(force:true);}
  }
}
