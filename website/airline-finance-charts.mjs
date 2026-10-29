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
function drawCash(doc,root,points){
 if(!root)return;
 if(!points.length){empty(doc,root,'Cash history is not available yet');return;}
 const svg=shell(doc,root,points.length===1?
   'One verified cash balance point. No historical trend is available.':
   'Cash balance history from the latest '+points.length+' verified ledger events');
 const min=Math.min(...points.map(p=>p.value)),max=Math.max(...points.map(p=>p.value));
 const spread=Math.max(max-min,Math.max(Math.abs(max),1)*0.03);
 const low=Math.max(0,min-spread*.25),high=max+spread*.25;
 const xAt=i=>points.length===1?326:72+i*(506/(points.length-1));
 const yAt=value=>219-(value-low)/(high-low)*178;
 if(points.length>1){
  svg.append(node(doc,'polyline',{points:points.map((p,i)=>xAt(i)+','+yAt(p.value)).join(' '),
   fill:'none',stroke:'#1b76c0','stroke-width':3,'stroke-linecap':'round',
   'stroke-linejoin':'round'}));
 }
 points.forEach((p,i)=>{
  svg.append(node(doc,'circle',{cx:xAt(i),cy:yAt(p.value),r:5,
   fill:'#ff6917',stroke:'#fff','stroke-width':2}));
 });
 svg.append(node(doc,'text',{x:8,y:42,class:'finance-chart-axis-label'},compact(high)));
 svg.append(node(doc,'text',{x:8,y:220,class:'finance-chart-axis-label'},compact(low)));
 const first=points[0],last=points[points.length-1];
 const date=t=>new Intl.DateTimeFormat('en-GB',{timeZone:'Europe/Berlin',day:'2-digit',
   month:'short'}).format(new Date(t));
 svg.append(node(doc,'text',{x:points.length===1?326:72,y:250,'text-anchor':points.length===1?'middle':'start',
  class:'finance-chart-axis-label'},date(first.time)));
 if(points.length>1)svg.append(node(doc,'text',{x:578,y:250,'text-anchor':'end',
   class:'finance-chart-axis-label'},date(last.time)));
 if(points.length===1)svg.append(node(doc,'text',{x:326,y:Math.max(20,yAt(first.value)-13),
  'text-anchor':'middle',class:'finance-chart-point-label'},usd(first.value)));
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
 const cashPoints=ledgerBalancePoints(cash,ledgerEntries);
 drawCash(doc,cashRoot,cashPoints);
 if(cashCaption)cashCaption.textContent=cashPoints.length===1?
  'One real ledger point is recorded. A balance trend will develop as new transactions occur.':
  cashPoints.length>1?'Based on the latest '+cashPoints.length+' verified financial transactions.':
  'Cash history will appear once your airline has recorded ledger transactions.';
 const opPoints=operatingMonthlyPoints(ledgerEntries);
 drawOperating(doc,incomeRoot,opPoints);
 if(incomeCaption)incomeCaption.textContent=opPoints.length?
  'Income and expenses use recognized operating ledger entries. Starting capital is excluded.':
  'No recorded operating revenues or expenses to graph yet. Starting capital is not income.';
}
