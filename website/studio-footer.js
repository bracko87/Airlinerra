/** Shared site-wide Airlinerra / Next Quest Studio footer.
 * No network calls, cookies or account data are required. The clock represents
 * real civil time in Germany, matching the real-time Airlinerra world clock.
 */
(function initStudioFooter(){
 'use strict';
 function updateClock(){
  const label=document.querySelector('[data-berlin-clock]');
  if(!label)return;
  const now=new Date();
  const formatter=new Intl.DateTimeFormat('en-GB',{
   timeZone:'Europe/Berlin',year:'numeric',month:'short',day:'2-digit',
   weekday:'short',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'
  });
  label.textContent=formatter.format(now)+' (Germany / Game time)';
  label.dateTime=now.toISOString();
 }
 function mount(){
  const footer=document.querySelector('footer');
  if(!footer || footer.dataset.studioFooter==='ready')return;
  // Preserve the public site's existing live connection-status widget, with
  // its attached retry event listeners and original DOM IDs.
  const existingHealth=footer.querySelector('.platform-health');
  if(existingHealth)existingHealth.remove();
  footer.className='studio-footer';
  footer.dataset.studioFooter='ready';
  footer.setAttribute('aria-label','Airlinerra website footer');
  footer.innerHTML=`
    <div class="studio-footer-inner">
      <div class="studio-footer-top">
        <div class="studio-footer-column studio-footer-brand">
          <a class="studio-footer-studio" href="https://nextqueststudio.net/" target="_blank" rel="noopener noreferrer">Next Quest Studio</a>
          <span>Independent simulation and management games.</span>
          <p class="studio-footer-time"><span class="studio-footer-clock-dot" aria-hidden="true"></span> Current time: <time data-berlin-clock>Germany / Game time</time></p>
        </div>
        <nav class="studio-footer-column" aria-label="Airlinerra pages">
          <strong>Airlinerra</strong>
          <a href="/">Home</a>
          <a href="/faq.html">FAQ</a>
          <a href="/pricing.html">Pricing</a>
          <a href="/register.html">Registration</a>
        </nav>
        <nav class="studio-footer-column" aria-label="Legal and support">
          <strong>Legal &amp; Support</strong>
          <a href="/terms.html">Terms and Conditions</a>
          <a href="/privacy.html">Privacy Policy</a>
          <a href="/impressum.html">Legal Notice</a>
          <a href="mailto:contact@nextqueststudio.net">Contact</a>
        </nav>
        <nav class="studio-footer-column" aria-label="More Next Quest Studio games">
          <strong>Our games</strong>
          <a href="https://propelotonmanager.com/" target="_blank" rel="noopener noreferrer">ProPeloton Manager</a>
          <a href="https://tennislegacygame.com/" target="_blank" rel="noopener noreferrer">Tennis Legacy: Rise to Glory</a>
        </nav>
      </div>
      <div class="studio-footer-bottom">
        <span>© <span data-studio-year>2026</span> <a href="https://nextqueststudio.net/" target="_blank" rel="noopener noreferrer">Next Quest Studio</a>. All rights reserved.</span>
        <span>Airlinerra - one real day = one game day</span>
      </div>
    </div>`;
  if(existingHealth){
   const place=footer.querySelector('.studio-footer-bottom');
   place.append(existingHealth);
  }
  const year=footer.querySelector('[data-studio-year]');
  if(year)year.textContent=new Intl.DateTimeFormat('en-GB',{timeZone:'Europe/Berlin',year:'numeric'}).format(new Date());
  updateClock();
  window.setInterval(updateClock,1000);
 }
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',mount,{once:true});
 else mount();
})();
