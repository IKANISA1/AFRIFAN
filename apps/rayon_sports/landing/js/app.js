const landingBranding = window.afriLandingBranding ?? {
  currencyCode: document.documentElement.dataset.currencyCode?.trim() || 'LOCAL',
  currencySymbol:
    document.documentElement.dataset.currencySymbol?.trim() ||
    document.documentElement.dataset.currencyCode?.trim() ||
    'LOCAL',
  currencyName:
    document.documentElement.dataset.currencyName?.trim() ||
    document.documentElement.dataset.currencyCode?.trim() ||
    'Local currency',
  normalizeAmount(raw) {
    if (typeof raw === 'number' && Number.isFinite(raw)) return raw;
    const digits = Number.parseInt(
      String(raw ?? '').replace(/[^\d-]/g, ''),
      10,
    );
    return Number.isFinite(digits) ? digits : 0;
  },
  formatCurrencyCode(amount) {
    return `${this.currencyCode} ${this.normalizeAmount(amount).toLocaleString()}`;
  },
  formatMembershipPrice(amount) {
    return `${this.formatCurrencyCode(amount)} per month`;
  },
};

/* ??????????????????????????????????????????
   DATA
?????????????????????????????????????????? */
const PLAYERS = [
  {name:'Kassim Ndayisenga',pos:'Goalkeeper',num:29,nat:'???? Rwanda',dob:'14 Jun 1998',ht:'1.88m',ft:'Right',since:'2021',emoji:'??',cat:'gk',stats:[{n:'22',l:'Apps'},{n:'0',l:'Goals'},{n:'9',l:'Clean Sheets'},{n:'28',l:'Saves'}],career:[{y:'2021Now',c:'Rayon Sports FC',a:'72 apps'},{y:'201821',c:'AS Kigali',a:'58 apps'},{y:'201618',c:'Bugesera FC',a:'26 apps'}]},
  {name:'Sadam Nyandwi',pos:'Centre Back',num:5,nat:'???? Rwanda',dob:'3 Feb 1996',ht:'1.85m',ft:'Right',since:'2019',emoji:'???',cat:'def',stats:[{n:'21',l:'Apps'},{n:'1',l:'Goals'},{n:'67',l:'Tackles'},{n:'2',l:'Yellow Cards'}],career:[{y:'2019Now',c:'Rayon Sports FC',a:'104 apps'},{y:'201619',c:'Mukura VS',a:'62 apps'},{y:'201416',c:'AS Kigali',a:'28 apps'}]},
  {name:'Yves Rwigema',pos:'Centre Back',num:4,nat:'???? Rwanda',dob:'8 Nov 1997',ht:'1.83m',ft:'Left',since:'2020',emoji:'???',cat:'def',stats:[{n:'20',l:'Apps'},{n:'2',l:'Goals'},{n:'72',l:'Tackles'},{n:'1',l:'Yellow Cards'}],career:[{y:'2020Now',c:'Rayon Sports FC',a:'94 apps'},{y:'201720',c:'Police FC',a:'55 apps'},{y:'201517',c:'Etincelles FC',a:'32 apps'}]},
  {name:'Jean Ngarambe',pos:'Right Back',num:2,nat:'???? Rwanda',dob:'18 May 2000',ht:'1.76m',ft:'Right',since:'2022',emoji:'???',cat:'def',stats:[{n:'19',l:'Apps'},{n:'0',l:'Goals'},{n:'2',l:'Assists'},{n:'62',l:'Tackles'}],career:[{y:'2022Now',c:'Rayon Sports FC',a:'52 apps'},{y:'201922',c:'Gasogi United',a:'38 apps'},{y:'201719',c:'Kigali FC (Youth)',a:'Academy'}]},
  {name:'Kevin Muhire',pos:'Central Midfielder',num:8,nat:'???? Rwanda',dob:'22 Aug 1999',ht:'1.76m',ft:'Right',since:'2022',emoji:'?',cat:'mid',stats:[{n:'19',l:'Apps'},{n:'3',l:'Goals'},{n:'5',l:'Assists'},{n:'87%',l:'Pass Acc.'}],career:[{y:'2022Now',c:'Rayon Sports FC',a:'58 apps'},{y:'201922',c:'APR FC',a:'48 apps'},{y:'201719',c:'Gasogi United',a:'24 apps'}]},
  {name:'Fabrice Mugheni',pos:'Defensive Midfielder',num:6,nat:'???? Rwanda',dob:'5 Mar 1995',ht:'1.80m',ft:'Right',since:'2018',emoji:'?',cat:'mid',stats:[{n:'22',l:'Apps'},{n:'1',l:'Goals'},{n:'3',l:'Assists'},{n:'88%',l:'Pass Acc.'}],career:[{y:'2018Now',c:'Rayon Sports FC',a:'148 apps'},{y:'201518',c:'AS Kigali',a:'62 apps'},{y:'201315',c:'Bugesera FC',a:'36 apps'}]},
  {name:'Nova Bayama',pos:'Attacking Midfielder',num:11,nat:'???? DR Congo',dob:'14 Jan 2001',ht:'1.74m',ft:'Both',since:'2023',emoji:'?',cat:'mid',stats:[{n:'20',l:'Apps'},{n:'4',l:'Goals'},{n:'7',l:'Assists'},{n:'85%',l:'Pass Acc.'}],career:[{y:'2023Now',c:'Rayon Sports FC',a:'44 apps'},{y:'202023',c:'TP Mazembe (Youth)',a:'38 apps'},{y:'201820',c:'Lupopo FC',a:'22 apps'}]},
  {name:'Ngagne Fall',pos:'Centre Forward',num:9,nat:'???? Senegal',dob:'12 Mar 1997',ht:'1.82m',ft:'Right',since:'2023',emoji:'?',cat:'fwd',stats:[{n:'22',l:'Apps'},{n:'14',l:'Goals'},{n:'5',l:'Assists'},{n:'72%',l:'Shot Acc.'}],career:[{y:'2023Now',c:'Rayon Sports FC',a:'44 apps'},{y:'202023',c:'Diambars FC',a:'78 apps'},{y:'201820',c:'AS Pikine',a:'42 apps'}]},
  {name:'Sunday Oni Jimoh',pos:'Right Winger',num:7,nat:'???? Nigeria',dob:'3 Jul 2000',ht:'1.72m',ft:'Left',since:'2024',emoji:'?',cat:'fwd',stats:[{n:'18',l:'Apps'},{n:'6',l:'Goals'},{n:'8',l:'Assists'},{n:'68%',l:'Dribble %'}],career:[{y:'2024Now',c:'Rayon Sports FC',a:'24 apps'},{y:'202224',c:'Enugu Rangers FC',a:'52 apps'},{y:'202022',c:'Heartland FC',a:'28 apps'}]},
];

/* ??????????????????????????????????????????
   LOADER
?????????????????????????????????????????? */
let pct=0;
const fillEl=document.getElementById('ldr-fill');
const ldrTimer=setInterval(()=>{
  pct+=Math.random()*20+8;
  if(pct>=100){pct=100;clearInterval(ldrTimer);setTimeout(()=>document.getElementById('loader').classList.add('done'),380)}
  fillEl.style.width=pct+'%';
},130);

/* ??????????????????????????????????????????
   HERO CANVAS PARTICLES
?????????????????????????????????????????? */
(function(){
  const c=document.getElementById('hero-canvas');
  const ctx=c.getContext('2d');
  let pts=[],mx=null,my=null;
  function resize(){c.width=c.offsetWidth;c.height=c.offsetHeight}
  function init(){
    pts=[];
    for(let i=0;i<60;i++) pts.push({
      x:Math.random()*c.width,y:Math.random()*c.height,
      vx:(Math.random()-.5)*.3,vy:(Math.random()-.5)*.3,
      r:Math.random()*1.6+.6,
      col:Math.random()>.4?'rgba(26,77,196,.6)':'rgba(201,168,.76,.48)'
    });
  }
  function draw(){
    ctx.clearRect(0,0,c.width,c.height);
    for(let i=0;i<pts.length;i++){
      for(let j=i+1;j<pts.length;j++){
        const dx=pts[i].x-pts[j].x,dy=pts[i].y-pts[j].y,d=Math.sqrt(dx*dx+dy*dy);
        if(d<105){ctx.beginPath();ctx.strokeStyle=`rgba(255,255,255,${.045*(1-d/105)})`;ctx.lineWidth=.4;ctx.moveTo(pts[i].x,pts[i].y);ctx.lineTo(pts[j].x,pts[j].y);ctx.stroke()}
      }
    }
    pts.forEach(p=>{
      ctx.beginPath();ctx.arc(p.x,p.y,p.r,0,Math.PI*2);ctx.fillStyle=p.col;ctx.fill();
      p.x+=p.vx;p.y+=p.vy;
      if(mx!==null){const dx=p.x-mx,dy=p.y-my,d=Math.sqrt(dx*dx+dy*dy);if(d<65){p.x+=dx/d*.9;p.y+=dy/d*.9}}
      if(p.x<0||p.x>c.width)p.vx*=-1;
      if(p.y<0||p.y>c.height)p.vy*=-1;
    });
    requestAnimationFrame(draw);
  }
  window.addEventListener('mousemove',e=>{const r=c.getBoundingClientRect();mx=e.clientX-r.left;my=e.clientY-r.top});
  window.addEventListener('resize',()=>{resize();init()});
  resize();init();draw();
})();

/* ??????????????????????????????????????????
   THEME
?????????????????????????????????????????? */
function toggleTheme(){
  const h=document.documentElement;
  const light=h.getAttribute('data-theme')==='light';
  h.setAttribute('data-theme',light?'dark':'light');
  document.getElementById('theme-ico').innerHTML=light
    ?'<path d="M8 1V2M8 14V15M1 8H2M14 8H15M3.05 3.05L3.76 3.76M12.24 12.24L12.95 12.95M3.05 12.95L3.76 12.24M12.24 3.76L12.95 3.05M8 5C6.34 5 5 6.34 5 8C5 9.66 6.34 11 8 11C9.66 11 11 9.66 11 8C11 6.34 9.66 5 8 5Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>'
    :'<path d="M14 8C14 11.31 11.31 14 8 14C4.69 14 2 11.31 2 8C2 4.69 4.69 2 8 2C5.8 4.07 5.8 11.93 8 14C10.2 11.93 10.2 4.07 8 2C11.31 2 14 4.69 14 8Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>';
}

/* ??????????????????????????????????????????
   SCROLL ANIMATIONS
?????????????????????????????????????????? */
const obs=new IntersectionObserver(entries=>entries.forEach(e=>{if(e.isIntersecting)e.target.classList.add('vis')}),{threshold:.08});
document.querySelectorAll('.anim').forEach(el=>obs.observe(el));

/* ??????????????????????????????????????????
   MATCH TABS
?????????????????????????????????????????? */
document.querySelectorAll('.tab[data-panel]').forEach(t=>t.addEventListener('click',()=>{
  document.querySelectorAll('.tab[data-panel]').forEach(x=>x.classList.remove('on'));
  document.querySelectorAll('.panel').forEach(x=>x.classList.remove('on'));
  t.classList.add('on');
  document.getElementById('panel-'+t.dataset.panel).classList.add('on');
}));

/* ??????????????????????????????????????????
   FIXTURE TABS
?????????????????????????????????????????? */
document.querySelectorAll('.tab[data-ftab]').forEach(t=>t.addEventListener('click',()=>{
  document.querySelectorAll('.tab[data-ftab]').forEach(x=>x.classList.remove('on'));
  t.classList.add('on');
  document.getElementById('ftab-results').style.display=t.dataset.ftab==='results'?'block':'none';
  document.getElementById('ftab-upcoming').style.display=t.dataset.ftab==='upcoming'?'block':'none';
}));

/* ??????????????????????????????????????????
   SQUAD GRID + FILTER
?????????????????????????????????????????? */
function buildSquad(filter='all'){
  const g=document.getElementById('squad-grid');
  const grads=['linear-gradient(180deg,#0A1F5C,#04081A)','linear-gradient(180deg,#1A2040,#04081A)','linear-gradient(180deg,#1F0A0A,#04081A)'];
  g.innerHTML=PLAYERS.filter(p=>filter==='all'||p.cat===filter).map((p,i)=>`
    <div class="pc anim" onclick="openPlayer(${PLAYERS.indexOf(p)})">
      <div class="pc-bg" style="background:${grads[i%3]}"><div style="font-size:70px;opacity:.35;margin-top:18px">${p.emoji}</div></div>
      <div class="pc-overlay"></div>
      <div class="pc-num">${p.num}</div>
      <div class="pc-body">
        <div class="pc-pos">${p.pos}</div>
        <div class="pc-name">${p.name.split(' ').slice(0,-1).join(' ')}<br>${p.name.split(' ').pop()}</div>
        <div class="pc-nat">${p.nat}</div>
      </div>
    </div>`).join('');
  g.querySelectorAll('.anim').forEach((el,i)=>{setTimeout(()=>obs.observe(el),i*30)});
}
buildSquad();
document.querySelectorAll('.sf').forEach(b=>b.addEventListener('click',()=>{
  document.querySelectorAll('.sf').forEach(x=>x.classList.remove('on'));
  b.classList.add('on');
  buildSquad(b.dataset.pos);
}));

/* ??????????????????????????????????????????
   PLAYER MODAL
?????????????????????????????????????????? */
function openPlayer(idx){
  const p=PLAYERS[idx];
  document.getElementById('pm-emoji').textContent=p.emoji;
  document.getElementById('pm-bignum').textContent=p.num;
  document.getElementById('pm-pos').textContent=p.pos;
  document.getElementById('pm-name').textContent=p.name;
  document.getElementById('pm-nat').textContent=p.nat;
  document.getElementById('pm-dob').textContent=p.dob;
  document.getElementById('pm-ht').textContent=p.ht;
  document.getElementById('pm-ft').textContent=p.ft;
  document.getElementById('pm-squad').textContent='#'+p.num;
  document.getElementById('pm-since').textContent=p.since;
  document.getElementById('pm-stats').innerHTML=p.stats.map(s=>`<div class="pst"><div class="pst-n">${s.n}</div><div class="pst-l">${s.l}</div></div>`).join('');
  document.getElementById('pm-career').innerHTML=p.career.map(c=>`<div class="career-row"><div class="career-yrs">${c.y}</div><div class="career-club">${c.c}</div><div class="career-apps">${c.a}</div></div>`).join('');
  document.getElementById('player-modal-bg').classList.add('open');
  document.body.style.overflow='hidden';
}
function closePM(e){if(e.target===document.getElementById('player-modal-bg'))closePMBtn()}
function closePMBtn(){document.getElementById('player-modal-bg').classList.remove('open');document.body.style.overflow=''}

/* ??????????????????????????????????????????
   VIDEO MODAL
?????????????????????????????????????????? */
let vidTimer;
function openVideo(title,meta){
  document.getElementById('vm-title').textContent=title;
  document.getElementById('vm-meta').textContent=meta;
  document.getElementById('vp-fill').style.width='0%';
  document.getElementById('video-modal-bg').classList.add('open');
  document.body.style.overflow='hidden';
}
function playVid(){
  const f=document.getElementById('vp-fill');
  let w=0;clearInterval(vidTimer);
  vidTimer=setInterval(()=>{w+=.4;f.style.width=w+'%';if(w>=100)clearInterval(vidTimer)},80);
}
function closeVM(e){if(e.target===document.getElementById('video-modal-bg'))closeVMBtn()}
function closeVMBtn(){document.getElementById('video-modal-bg').classList.remove('open');document.body.style.overflow='';clearInterval(vidTimer)}

/* ??????????????????????????????????????????
   JERSEY BUILDER
?????????????????????????????????????????? */
function updateJersey(){
  document.getElementById('jb-nametxt').textContent=(document.getElementById('jb-name').value||'').toUpperCase().slice(0,12);
  document.getElementById('jb-numtxt').textContent=document.getElementById('jb-num').value||'9';
}
function setJerseyCol(el,part,color){
  document.querySelectorAll(`.color-chip`).forEach(c=>{if(c.parentElement===el.parentElement)c.classList.remove('on')});
  el.classList.add('on');
  if(part==='body')document.getElementById('jb-body').setAttribute('fill',color);
  else{document.getElementById('jb-sl').setAttribute('fill',color);document.getElementById('jb-sr').setAttribute('fill',color)}
}
function setSz(btn){document.querySelectorAll('.size-btn').forEach(b=>b.classList.remove('on'));btn.classList.add('on')}
function addJersey(){
  const name=document.getElementById('jb-name').value||'FALL';
  const num=document.getElementById('jb-num').value||'9';
  const sz=document.querySelector('.size-btn.on')?.textContent||'M';
  addProd(`Custom Jersey #${num}  ${name}`,'cust-'+Date.now(),sz,45000);
}

/* ??????????????????????????????????????????
   CART
?????????????????????????????????????????? */
const cart=[];
function addProd(name,id,size,price){
  const ex=cart.find(i=>i.id===id&&i.size===size);
  if(ex)ex.qty++;else cart.push({name,id,size,price,qty:1});
  updateCartUI();openCart();
}
function updateCartUI(){
  const total=cart.reduce((s,i)=>s+i.price*i.qty,0);
  const count=cart.reduce((s,i)=>s+i.qty,0);
  document.getElementById('cart-total').textContent=landingBranding.formatCurrencyCode(total);
  const badge=document.getElementById('cart-badge');
  badge.textContent=count;badge.style.display=count>0?'flex':'none';
  const list=document.getElementById('cart-items');
  if(!cart.length){list.innerHTML='<div class="cart-empty"><div style="font-size:38px;opacity:.2">???</div><div>Your cart is empty</div></div>';return}
  list.innerHTML=cart.map((item,idx)=>`
    <div class="citem">
      <div class="citem-img" style="background:linear-gradient(135deg,var(--blue-p),var(--mid))">??</div>
      <div class="citem-info">
        <div class="citem-name">${item.name}</div>
        <div class="citem-meta">Size: ${item.size}  ${landingBranding.formatCurrencyCode(item.price)}</div>
        <div class="citem-ctrls">
          <button onclick="chgQty(${idx},-1)">?</button>
          <span>${item.qty}</span>
          <button onclick="chgQty(${idx},1)">+</button>
        </div>
      </div>
      <button class="citem-rm" onclick="rmItem(${idx})">?</button>
    </div>`).join('');
}
function chgQty(i,d){cart[i].qty+=d;if(cart[i].qty<=0)cart.splice(i,1);updateCartUI()}
function rmItem(i){cart.splice(i,1);updateCartUI()}
function openCart(){document.getElementById('cart-drawer').classList.add('open');document.getElementById('cart-overlay').classList.add('open');document.body.style.overflow='hidden'}
function closeCart(){document.getElementById('cart-drawer').classList.remove('open');document.getElementById('cart-overlay').classList.remove('open');document.body.style.overflow=''}
updateCartUI();

/* ??????????????????????????????????????????
   MEMBERSHIP MODAL
?????????????????????????????????????????? */
function openMembership(tier,price){
  document.getElementById('mem-title').textContent='Join '+tier;
  document.getElementById('mem-sub').textContent=landingBranding.formatMembershipPrice(
    landingBranding.normalizeAmount(price),
  );
  document.getElementById('mem-modal-bg').classList.add('open');
  document.body.style.overflow='hidden';
}
function closeMemBg(e){if(e.target===document.getElementById('mem-modal-bg'))closeMem()}
function closeMem(){document.getElementById('mem-modal-bg').classList.remove('open');document.body.style.overflow=''}
function completeMem(){alert('Welcome to Rayon Sports! Your membership is confirmed.\n\nA confirmation SMS will be sent to your phone shortly.\n\nGIKUNDIRO! ??');closeMem()}

/* ??????????????????????????????????????????
   TICKETS
?????????????????????????????????????????? */
let selMatch='',selZone='',zoneBasePrice=0,selMatchPrice=0;
function goStep(n){
  document.querySelectorAll('.tstep').forEach(s=>s.classList.remove('on'));
  document.querySelectorAll('.tpanel').forEach(p=>p.classList.remove('on'));
  document.querySelector(`.tstep[data-s="${n}"]`).classList.add('on');
  document.getElementById('tp'+n).classList.add('on');
}
function pickMatch(row,match,date,price){
  document.querySelectorAll('.mpick').forEach(r=>r.classList.remove('on'));
  row.classList.add('on');
  selMatch=match+'  '+date;selMatchPrice=price;
  setTimeout(()=>{goStep(2);document.getElementById('tp2-title').textContent=selMatch},150);
}
function pickZone(id,name,min,max){
  ['north','south','west','east'].forEach(z=>{
    const el=document.getElementById('z-'+z);
    el.setAttribute('fill',z==='west'||z==='east'?'rgba(201,168,76,.12)':'rgba(0,51,160,.28)');
  });
  const el=document.getElementById('z-'+id);
  el.setAttribute('fill',id==='west'||id==='east'?'rgba(201,168,76,.45)':'rgba(0,51,160,.58)');
  selZone=name;zoneBasePrice=min;
  document.getElementById('seat-selection').innerHTML=`
    <div style="font-size:8.5px;letter-spacing:2px;text-transform:uppercase;color:var(--gold);font-weight:700;margin-bottom:7px">${name} Selected</div>
    <div style="font-size:11.5px;color:var(--text2)">${landingBranding.formatCurrencyCode(min)}  ${landingBranding.formatCurrencyCode(max)} per ticket</div>`;
  const btn=document.getElementById('tp2-proceed');
  btn.removeAttribute('disabled');btn.style.opacity='1';
}
function goToCheckout(){refreshOrder();goStep(3)}
function refreshOrder(){
  const qty=parseInt(document.getElementById('tkt-qty')?.value||1);
  document.getElementById('order-txt').innerHTML=`<strong style="color:var(--text)">${selMatch}</strong><br>${selZone}  ${qty} ticket${qty>1?'s':''}<br><strong style="color:var(--gold)">Total: ${landingBranding.formatCurrencyCode(zoneBasePrice*qty)}</strong>`;
}
function confirmOrder(){alert('Tickets booked! A confirmation SMS has been sent to your phone.\n\nEnjoy the match!\nGIKUNDIRO! ???');goStep(1);document.querySelectorAll('.mpick').forEach(r=>r.classList.remove('on'))}

/* ??????????????????????????????????????????
   MOBILE MORE DRAWER
?????????????????????????????????????????? */
function toggleMore(){document.getElementById('more-drawer').classList.toggle('open')}
function closeMore(){document.getElementById('more-drawer').classList.remove('open')}
window.addEventListener('scroll',closeMore);
