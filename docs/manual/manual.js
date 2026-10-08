'use strict';
const sidebar=document.querySelector('.sidebar');
const toggle=document.querySelector('.nav-toggle');
const navLinks=[...document.querySelectorAll('.sidebar nav a')];
const sections=[...document.querySelectorAll('main section')];
const search=document.querySelector('#search');
const status=document.querySelector('#search-status');
const searchText=new Map(sections.map(s=>[s.id,s.textContent.toLowerCase()]));
search.addEventListener('input',()=>{
 const q=search.value.trim().toLowerCase();let count=0;
 navLinks.forEach(a=>{const match=!q||(searchText.get(a.hash.slice(1))||'').includes(q);a.hidden=!match;if(match)count++;});
 status.textContent=q?`${count} matching chapter${count===1?'':'s'}`:'';
});
toggle.addEventListener('click',()=>{const open=sidebar.classList.toggle('open');toggle.setAttribute('aria-expanded',String(open));if(open)search.focus();});
navLinks.forEach(a=>a.addEventListener('click',()=>{sidebar.classList.remove('open');toggle.setAttribute('aria-expanded','false');}));
document.addEventListener('keydown',event=>{if(event.key==='Escape'){sidebar.classList.remove('open');toggle.setAttribute('aria-expanded','false');}});
document.querySelectorAll('[data-control]').forEach(button=>button.addEventListener('click',()=>{
 document.querySelectorAll('[data-control]').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));
 document.querySelectorAll('[data-device]').forEach(panel=>panel.hidden=button.dataset.control!=='all'&&panel.dataset.device!==button.dataset.control);
}));
let scheduled=false;
function updateReading(){scheduled=false;const extent=document.documentElement.scrollHeight-innerHeight;document.querySelector('.reading-progress').style.width=`${extent>0?Math.min(100,scrollY/extent*100):0}%`;let active='';for(const s of sections){if(s.getBoundingClientRect().top<160)active=s.id;}navLinks.forEach(a=>{const isActive=a.hash==='#'+active;a.classList.toggle('active',isActive);if(isActive)a.setAttribute('aria-current','location');else a.removeAttribute('aria-current');});}
addEventListener('scroll',()=>{if(!scheduled){scheduled=true;requestAnimationFrame(updateReading);}},{passive:true});
addEventListener('resize',updateReading);updateReading();
document.querySelector('.print-button').addEventListener('click',()=>window.print());
