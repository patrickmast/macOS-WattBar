/* WattBar landing — interactions */
(() => {
  'use strict';
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---- nav scrolled state ---- */
  const nav = document.getElementById('nav');
  const onScroll = () => nav.classList.toggle('scrolled', window.scrollY > 12);
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  /* ---- scroll reveal ---- */
  const reveals = document.querySelectorAll('.reveal:not(.in)');
  if (reduce) {
    reveals.forEach(el => el.classList.add('in'));
  } else {
    const io = new IntersectionObserver((entries) => {
      entries.forEach(e => {
        if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
      });
    }, { threshold: 0.16, rootMargin: '0px 0px -8% 0px' });
    reveals.forEach(el => io.observe(el));
  }

  /* ---- gauge geometry ---- */
  const MAX_W = 100;                 // gauge full scale
  const A0 = 180, A1 = 360;          // arc sweep, in degrees (left → right, top half)
  const arc = document.getElementById('arc');
  const needle = document.getElementById('needle');
  const ticksG = document.getElementById('ticks');
  const ARC_LEN = 502;               // measured path length

  // tick marks
  if (ticksG) {
    const cx = 200, cy = 200, rOuter = 160 + 12, rInner = 160 - 12;
    for (let i = 0; i <= 10; i++) {
      const t = i / 10;
      const ang = (A0 + (A1 - A0) * t) * Math.PI / 180;
      const major = i % 5 === 0;
      const ri = major ? rInner - 4 : rInner + 3;
      const x1 = cx + Math.cos(ang) * rOuter, y1 = cy + Math.sin(ang) * rOuter;
      const x2 = cx + Math.cos(ang) * ri,     y2 = cy + Math.sin(ang) * ri;
      const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
      line.setAttribute('x1', x1.toFixed(1)); line.setAttribute('y1', y1.toFixed(1));
      line.setAttribute('x2', x2.toFixed(1)); line.setAttribute('y2', y2.toFixed(1));
      line.setAttribute('stroke', major ? 'rgba(255,255,255,0.35)' : 'rgba(255,255,255,0.15)');
      line.setAttribute('stroke-width', major ? '2' : '1.2');
      line.setAttribute('stroke-linecap', 'round');
      ticksG.appendChild(line);
    }
  }

  const gNum = document.getElementById('gNum');
  const gFlow = document.getElementById('gFlow');
  const gFlowText = document.getElementById('gFlowText');
  const gCaption = document.getElementById('gCaption');
  const mbWatt = document.getElementById('mbWatt');

  let cur = 0;        // current displayed watts (for smoothing)
  let target = 42.3;

  function render(w) {
    const clamped = Math.max(0, Math.min(MAX_W, Math.abs(w)));
    const frac = clamped / MAX_W;
    // arc
    if (arc) arc.setAttribute('stroke-dashoffset', (ARC_LEN * (1 - frac)).toFixed(1));
    // needle: A0 → A1 maps to rotation 0 → 180
    if (needle) needle.setAttribute('transform', `rotate(${(frac * 180).toFixed(1)} 200 200)`);
    // readout
    if (gNum) gNum.textContent = clamped.toFixed(1);
  }

  // realistic scripted sequence: charge ramp → settle → unplug → drain
  const script = [
    { w: 8.2,  flow: 'in',  status: 'Charging',   cap: 'into the battery', dur: 1400 },
    { w: 34.6, flow: 'in',  status: 'Charging',   cap: 'into the battery', dur: 1600 },
    { w: 61.0, flow: 'in',  status: 'Fast charge', cap: 'into the battery', dur: 1600 },
    { w: 42.3, flow: 'in',  status: 'Charging',   cap: 'into the battery', dur: 2000 },
    { w: 11.4, flow: 'in',  status: 'Topping off', cap: 'into the battery', dur: 1800 },
    { w: 19.8, flow: 'out', status: 'On battery',  cap: 'out of the battery', dur: 2200 },
    { w: 7.5,  flow: 'out', status: 'On battery',  cap: 'out of the battery', dur: 2000 },
  ];
  let step = 0;

  function setFlow(flow, status, cap) {
    if (flow === 'in') {
      gFlow.className = 'gauge-flow charging';
      gFlow.querySelector('circle').setAttribute('fill', '#30d158');
      gFlow.querySelectorAll('path').forEach(p => p.setAttribute('d', p.getAttribute('d'))); // keep plus
      gFlow.innerHTML = '<svg width="12" height="12" viewBox="0 0 12 12"><circle cx="6" cy="6" r="6" fill="currentColor"/><path d="M6 3v6M3 6h6" stroke="#0a0a0b" stroke-width="1.6" stroke-linecap="round"/></svg><span>' + status + '</span>';
    } else {
      gFlow.className = 'gauge-flow draining';
      gFlow.innerHTML = '<svg width="12" height="12" viewBox="0 0 12 12"><circle cx="6" cy="6" r="6" fill="currentColor"/><path d="M3 6h6" stroke="#0a0a0b" stroke-width="1.6" stroke-linecap="round"/></svg><span>' + status + '</span>';
    }
    if (gCaption) gCaption.textContent = cap;
  }

  function tween(from, to, dur, done) {
    if (reduce) { render(to); cur = to; done && done(); return; }
    const t0 = performance.now();
    function frame(now) {
      const p = Math.min(1, (now - t0) / dur);
      const e = 1 - Math.pow(1 - p, 3); // easeOutCubic
      const v = from + (to - from) * e;
      cur = v; render(v);
      if (mbWatt) mbWatt.textContent = Math.round(Math.abs(v)) + (script[step] && script[step].flow === 'out' ? '%' : 'W');
      if (p < 1) requestAnimationFrame(frame);
      else done && done();
    }
    requestAnimationFrame(frame);
  }

  function runStep() {
    const s = script[step];
    setFlow(s.flow, s.status, s.cap);
    // menu bar shows watt while charging, a faux % while on battery
    tween(cur, s.w, s.dur * 0.55, () => {
      setTimeout(() => {
        step = (step + 1) % script.length;
        runStep();
      }, s.dur * 0.45);
    });
  }

  // kick off once the gauge scrolls into view (or immediately if reduced motion)
  if (reduce) {
    render(42.3);
  } else {
    const gaugeEl = document.querySelector('.instrument');
    let started = false;
    const gio = new IntersectionObserver((entries) => {
      entries.forEach(e => {
        if (e.isIntersecting && !started) { started = true; runStep(); gio.disconnect(); }
      });
    }, { threshold: 0.4 });
    if (gaugeEl) gio.observe(gaugeEl);
  }

  /* ---- fetch real DMG size from GitHub release (best-effort) ---- */
  fetch('https://api.github.com/repos/patrickmast/macOS-WattBar/releases/latest')
    .then(r => r.ok ? r.json() : null)
    .then(data => {
      if (!data || !data.assets) return;
      const asset = data.assets.find(a => /latest\.dmg$/.test(a.name)) || data.assets[0];
      if (asset && asset.size) {
        const mb = (asset.size / 1048576).toFixed(1);
        const el = document.getElementById('dmgSize');
        if (el) el.textContent = '~' + mb + ' MB';
      }
    })
    .catch(() => {});
})();
