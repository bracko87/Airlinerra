/** SVG financial charts driven only by authenticated ledger entries.
 * No fabricated revenue, expense, or time periods. Starting capital is NOT
 * operating income, and unrecognized transaction kinds are not classified.
 */
const NS='http://www.w3.org/2000/svg';
const INCOME=new Set(['PASSENGER_REVENUE','TICKET_REVENUE','CARGO_REVENUE','ANCILLARY_REVENUE','ROUTE_REVENUE','OPERATING_REVENUE','FARE_REVENUE']);
const EXPENSE=new Set(['FUEL_COST','FUEL_EXPENSE','AIRPORT_FEE','AIRPORT_FEES','STAFF_SALARY','STAFF_COST','CREW_COST','MAINTENANCE_COST','LEASE_PAYMENT','LEASE_COST','SERVICE_COST','MARKETING_COST','INSURANCE_COST','OPERATING_EXPENSE']);
export function ledgerBalancePoints(balance,entries){
 const current=Number(balance);
 if(!Number.isFinite(current)||current<0||!Array.isArray(entries))return [];
 const valid=entries.filter(e=>
  typeof e?.kind==='string'&&typeof e?.recordedAt==='string'&&Number.isFinite(Date.parse(e.recordedAt))&&
  (typeof e?.amountUsd==='string'||typeof e?.amountUsd==='number')&&
  Number.isFinite(Number(e.amountUsd)));
 const chronological=valid.slice().sort((a,b)=>Date.parse(a.recordedAt)-Date.parse(b.recordedAt));
 let running=current;
 const output=new Array(chronological.length);
 for(let i=chronological.length-1;i>=0;i--){
  output[i]={time:chronological[i].recordedAt,value:running};
  running-=Number(chronological[i].amountUsd);
 }
 return output.filter(p=>Number.isFinite(p.value)&&p.value>=0);
}
export function operatingMonthlyPoints(entries){
 if(!Array.isArray(entries))return [];
 const periods=new Map();
 for(const item of entries){
  const key=INCOME.has(item?.kind)?'income':EXPENSE.has(item?.kind)?'expense':null;
  const n=Number(item?.amountUsd),t=Date.parse(item?.recordedAt);
  if(!key||!Number.isFinite(n)||!Number.isFinite(t))continue;
  // Explicitly named income/expense ledger kinds avoid classifying capital
  // contributions or transfers as operating income.
  const period=new Date(t).toISOString().slice(0,7);
  if(!periods.has(period))periods.set(period,{period,income:0,expense:0});
  periods.get(period)[key]+=Math.abs(n);
 }
 return [...periods.values()].sort((a,b)=>a.period.localeCompare(b.period)).slice(-4);
}
const usd=value=>new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',
  maximumFractionDigits:0}).format(value);
const compact=value=>new Intl.NumberFormat('en-US',{notation:'compact',
 maximumFractionDigits:1}).format(value);
function node(doc,tag,attributes={},text){
 const n=doc.createElementNS(NS,tag);
 for(const [name,val] of Object.entries(attributes))n.setAttribute(name,String(val));
 if(text!==undefined)n.textContent=text;
 return n;
}
function shell(doc,root,label){
 root.replaceChildren();
 const svg=node(doc,'svg',{viewBox:'0 0 620 260',width:'100%',height:'260',
  role:'img','aria-label':label,preserveAspectRatio:'xMidYMid meet'});
 const grid=node(doc,'g',{class:'finance-chart-grid'});
 for(let i=0;i<4;i++){
  const y=38+i*57;
  grid.append(node(doc,'line',{x1:61,y1:y,x2:592,y2:y}));
 }
 svg.append(grid);
 root.append(svg);
 root.setAttribute('aria-label',label);
 return svg;
}
function empty(doc,root,text){
 const svg=shell(doc,root,text);
 svg.append(node(doc,'text',{x:326,y:125,'text-anchor':'middle',
  class:'finance-chart-empty-label'},text));
 svg.append(node(doc,'text',{x:326,y:151,'text-anchor':'middle',
  class:'finance-chart-empty-hint'},'No simulated financial results are displayed.'));
}
/** Real available cash plus verified known operating cost movements.
 * One category is explicitly valid when no operating costs have been recorded.
 */
export function verifiedCashMix(cash,entries){
 const balance=Number(cash);
 if((typeof cash!=='string'&&typeof cash!=='number')||!Number.isFinite(balance)||balance<0)return null;
 const costs=operatingMonthlyPoints(entries).reduce((total,p)=>total+p.expense,0);
 if(!Number.isFinite(costs)||costs<0)return null;
 const total=balance+costs;
 return Object.freeze({balance,costs,total,cashShare:total>0?balance/total:0});
}
function drawCash(doc,root,mix){
 if(!root)return;
 root.replaceChildren();
 if(!mix){
  empty(doc,root,'Cash breakdown unavailable');return;
 }
 const wrapper=doc.createElement('div');wrapper.className='dashboard-donut-chart';
 const svg=node(doc,'svg',{viewBox:'0 0 240 240',role:'img',
  'aria-label':'Verified financial composition: available cash '+usd(mix.balance)+
   ', recorded operating costs '+usd(mix.costs)});
 const ring=node(doc,'circle',{cx:120,cy:120,r:86,fill:'none',stroke:'#092b57','stroke-width':29});
 svg.append(ring);
 if(mix.costs>0&&mix.total>0){
  const pct=mix.costs/mix.total,perimeter=2*Math.PI*86;
  const expenseArc=node(doc,'circle',{cx:120,cy:120,r:86,fill:'none',
   stroke:'#ff6917','stroke-width':29,'stroke-dasharray':String(pct*perimeter)+' '+String(perimeter),
   transform:'rotate(-90 120 120)'});
  svg.append(expenseArc);
 }
 svg.append(node(doc,'circle',{cx:120,cy:120,r:64,fill:'#f5f9fe',stroke:'#dce8f6','stroke-width':1}));
 svg.append(node(doc,'text',{x:120,y:115,'text-anchor':'middle',
  fill:'#526b87','font-size':13},'AVAILABLE CASH'));
 svg.append(node(doc,'text',{x:120,y:141,'text-anchor':'middle',
  fill:'#092b57','font-weight':800,'font-size':24},compact(mix.balance)));
 const legend=doc.createElement('div');legend.className='dashboard-donut-info';
 const title=doc.createElement('strong');title.textContent=usd(mix.balance);
 const available=doc.createElement('div');available.className='dashboard-donut-item';
 const circle=doc.createElement('span');circle.className='dashboard-donut-key';
 const a=doc.createElement('span');a.textContent='Available airline funds';available.append(circle,a);
 const expense=doc.createElement('div');expense.className='dashboard-donut-item';
 const orange=doc.createElement('span');orange.className='dashboard-donut-key orange';
 const b=doc.createElement('span');b.textContent=mix.costs>0?
  'Recognized operating costs: '+usd(mix.costs):'Operating costs: not recorded';
 expense.append(orange,b);
 const note=doc.createElement('small');
 note.textContent=mix.costs>0?'Shares of available cash plus recorded operating costs.':
  'One verified category. No fictional cost slice added.';
 legend.append(title,available,expense,note);wrapper.append(svg,legend);root.append(wrapper);
 root.setAttribute('aria-label','Verified cash balance '+usd(mix.balance)+
  ', recorded operating costs '+usd(mix.costs));
}
function drawOperating(doc,root,points){
 if(!root)return;
 if(!points.length){empty(doc,root,'No operating income or expenses recorded yet');return;}
 const svg=shell(doc,root,'Verified operating income and expenses by recorded month');
 const max=Math.max(1,...points.flatMap(p=>[p.income,p.expense]));
 points.forEach((p,i)=>{
  const midpoint=(i+.5)*520/points.length+65;
  const width=Math.min(34,125/points.length);
  for(const [index,key,fill] of [[0,'income','#1679bd'],[1,'expense','#ff8a3d']]){
   const value=p[key],h=value/max*172;
   if(value>0)svg.append(node(doc,'rect',{
    x:midpoint+(index===0?-width-2:2),y:217-h,width,height:h,rx:3,fill
   }));
  }
  const name=new Intl.DateTimeFormat('en-GB',{timeZone:'UTC',month:'short',year:'2-digit'})
    .format(new Date(p.period+'-01T00:00:00Z'));
  svg.append(node(doc,'text',{x:midpoint,y:250,'text-anchor':'middle',
   class:'finance-chart-axis-label'},name));
 });
 svg.append(node(doc,'text',{x:8,y:40,class:'finance-chart-axis-label'},compact(max)));
 svg.append(node(doc,'text',{x:20,y:221,class:'finance-chart-axis-label'},'0'));
}
export function renderFinancialCharts(doc,{cash=null,ledgerEntries=null}={}){
 const cashRoot=doc.getElementById('dashboard-cash-chart');
 const incomeRoot=doc.getElementById('dashboard-income-chart');
 const cashCaption=doc.getElementById('dashboard-cash-caption');
 const incomeCaption=doc.getElementById('dashboard-income-caption');
 const mix=verifiedCashMix(cash,ledgerEntries);
 drawCash(doc,cashRoot,mix);
 if(cashCaption)cashCaption.textContent=mix?
  'Navy: actual available funds. Orange: recorded operating costs, if any. No sample figures.':
  'Verified financial composition will appear when your airline balance is available.';
 const opPoints=operatingMonthlyPoints(ledgerEntries);
 drawOperating(doc,incomeRoot,opPoints);
 if(incomeCaption)incomeCaption.textContent=opPoints.length?
  'Income and expenses use recognized operating ledger entries. Starting capital is excluded.':
  'No recorded operating revenues or expenses to graph yet. Starting capital is not income.';
}
