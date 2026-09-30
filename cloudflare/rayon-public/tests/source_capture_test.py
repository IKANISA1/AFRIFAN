"""No network: actual urllib redirect chain with a mocked HTTPS transport."""
import io
import json
import pathlib
import sys
import unittest
from email.message import Message
from unittest.mock import patch
from urllib.response import addinfourl
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/scripts'))
import snapshot_gikundiro_public_for_cloudflare as source

class SourceCaptureBoundaryTests(unittest.TestCase):
    def transport(self, calls, redirect=False, status=200):
        def open_request(handler, request):
            calls.append(request.full_url)
            headers=Message();headers['Content-Type']='application/json'
            code=status
            if redirect and len(calls)==1:
                headers['Location']='https://unapproved.example.invalid/collect';code=302
            response=addinfourl(io.BytesIO(json.dumps([]).encode()),headers,request.full_url,code)
            response.msg='Synthetic response'
            return response
        return open_request

    def test_cross_host_redirect_is_rejected_before_a_second_request(self):
        calls=[]
        with patch.object(urllib.request,'_opener',None), patch.object(urllib.request.HTTPSHandler,'https_open',self.transport(calls,True)), patch.object(urllib.request.HTTPHandler,'http_open',self.transport(calls,True)):
            with self.assertRaisesRegex(RuntimeError,'redirect'):
                source.fetch('https://'+source.EXPECTED_HOST,'synthetic','news_posts',{'select':'id'})
        self.assertEqual(len(calls),1,'API headers must never reach a redirected host')

    def test_valid_fixed_source_uses_only_expected_https_origin(self):
        calls=[]
        with patch.object(urllib.request,'_opener',None), patch.object(urllib.request.HTTPSHandler,'https_open',self.transport(calls)), patch.object(urllib.request.HTTPHandler,'http_open',self.transport(calls)):
            self.assertEqual(source.fetch('https://'+source.EXPECTED_HOST,'synthetic','news_posts',{'select':'id'}),[])
        self.assertEqual(len(calls),1)
        self.assertTrue(calls[0].startswith('https://'+source.EXPECTED_HOST+'/rest/v1/news_posts?'))

    def test_invalid_source_url_is_rejected_before_transport(self):
        invalid=[
            'https://synthetic-user:synthetic-secret@'+source.EXPECTED_HOST,
            'https://'+source.EXPECTED_HOST+':8443',
            'https://'+source.EXPECTED_HOST+'/unexpected',
            'https://'+source.EXPECTED_HOST+'?override=1',
            'https://'+source.EXPECTED_HOST+'#fragment',
            'https://unapproved.example.invalid',
            'http://'+source.EXPECTED_HOST,
        ]
        for base in invalid:
            with self.subTest(case=invalid.index(base)):
                calls=[]
                with patch.object(urllib.request,'_opener',None), patch.object(urllib.request.HTTPSHandler,'https_open',self.transport(calls)), patch.object(urllib.request.HTTPHandler,'http_open',self.transport(calls)):
                    with self.assertRaises(RuntimeError):
                        source.fetch(base,'synthetic','news_posts',{'select':'id'})
                self.assertEqual(calls,[])

    def test_upstream_http_error_does_not_expose_url_or_key(self):
        calls=[]
        with patch.object(urllib.request,'_opener',None), patch.object(urllib.request.HTTPSHandler,'https_open',self.transport(calls,status=502)), patch.object(urllib.request.HTTPHandler,'http_open',self.transport(calls,status=502)):
            with self.assertRaises(RuntimeError) as raised:
                source.fetch('https://'+source.EXPECTED_HOST,'synthetic','news_posts',{'select':'id'})
        self.assertEqual(str(raised.exception),'Public news_posts query returned HTTP 502')

if __name__=='__main__':unittest.main()
