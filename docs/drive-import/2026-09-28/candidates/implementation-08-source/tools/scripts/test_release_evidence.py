import json,unittest
from release_evidence import validate,REQUIRED
from release_artifact import ArtifactError
class EvidenceTests(unittest.TestCase):
 def setUp(self):
  self.now=1800000000000;self.sha='a'*40;self.artifact='b'*64
  self.v={'schemaVersion':1,'candidateSha':self.sha,'artifactSha256':self.artifact,'expiresAtMs':self.now+60000,'checks':[{'id':x,'status':'approved','reviewer':'synthetic-test-reviewer','evidenceRef':'test:synthetic-only','verifiedAtMs':self.now-1} for x in sorted(REQUIRED)]}
 def runv(self):return validate(json.dumps(self.v),self.sha,self.artifact,self.now)
 def denied(self):
  with self.assertRaises((ArtifactError,TypeError)):self.runv()
 def test_valid_declaration_not_truth(self):self.assertFalse(self.runv()['evidenceTruthIndependentlyVerified'])
 def test_absent(self):
  with self.assertRaises(ArtifactError):validate('',self.sha,self.artifact,self.now)
 def test_wrong_commit(self):self.v['candidateSha']='c'*40;self.denied()
 def test_wrong_artifact(self):self.v['artifactSha256']='c'*64;self.denied()
 def test_unknown_topfield(self):self.v['approved']=True;self.denied()
 def test_missing_check(self):self.v['checks'].pop();self.denied()
 def test_duplicate(self):self.v['checks'][1]=self.v['checks'][0];self.denied()
 def test_expired(self):self.v['expiresAtMs']=self.now;self.denied()
 def test_far_future(self):self.v['expiresAtMs']=self.now+86400001;self.denied()
 def test_false_schema(self):self.v['schemaVersion']=True;self.denied()
 def test_invented_check(self):self.v['checks'][0]['id']='tests_passed';self.denied()
 def test_blank_reviewer(self):self.v['checks'][0]['reviewer']='';self.denied()
 def test_blank_evidence(self):self.v['checks'][0]['evidenceRef']='';self.denied()
 def test_stale(self):self.v['checks'][0]['verifiedAtMs']=self.now-86400001;self.denied()
 def test_future(self):self.v['checks'][0]['verifiedAtMs']=self.now+1;self.denied()
 def test_bool_time(self):self.v['checks'][0]['verifiedAtMs']=True;self.denied()
 def test_check_extrafield(self):self.v['checks'][0]['waiver']=True;self.denied()
for status in ['open','pending','pass',True,'skipped','waived','not_applicable']:
 def test(self,status=status):self.v['checks'][0]['status']=status;self.denied()
 setattr(EvidenceTests,'test_bad_status_'+str(status),test)
if __name__=='__main__':unittest.main()
