// Isolated QA entry. Never imported by Next or a deployed application.
import {useEffect,useState} from 'react';
import {createRoot} from 'react-dom/client';
import {BrowserMembershipPortal} from '../../src/components/browser-membership-portal';

declare global {
 interface Window {
  __AFRICLUB_CONTROLLED_FIXTURE__: {setClub:(clubId:number)=>void;unmount:()=>void};
 }
}
const root=createRoot(document.getElementById('root')!);
function ControlledFixture(){
 const [clubId,setClub]=useState(24);
 useEffect(()=>{
  window.__AFRICLUB_CONTROLLED_FIXTURE__={setClub,unmount:()=>root.unmount()};
 },[]);
 return <main><BrowserMembershipPortal origin={window.location.origin} clubId={clubId}
  clubName={clubId===24?'Synthetic Club A':'Synthetic Club B'}/></main>;
}
root.render(<ControlledFixture/>);
