/* Busa Guest House Group demo site: menu, gallery, lightbox, demo forms */
(function () {
  'use strict';

  var doc = document.documentElement;

  /* ---------- Mobile menu ---------- */
  var toggle = document.querySelector('.menu-toggle');
  var header = document.querySelector('.site-header');
  function setNavTop() {
    if (!header) return;
    var r = header.getBoundingClientRect();
    doc.style.setProperty('--nav-top', Math.max(0, r.bottom) + 'px');
  }
  if (toggle) {
    toggle.addEventListener('click', function () {
      setNavTop();
      var open = doc.classList.toggle('nav-open');
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
      toggle.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
      document.body.style.overflow = open ? 'hidden' : '';
    });
    window.addEventListener('resize', function () {
      if (window.innerWidth > 920 && doc.classList.contains('nav-open')) {
        doc.classList.remove('nav-open');
        toggle.setAttribute('aria-expanded', 'false');
        document.body.style.overflow = '';
      }
    });
  }

  /* Desktop dropdown: open on click for touch and keyboard users */
  document.querySelectorAll('.nav .nav-parent').forEach(function (btn) {
    btn.addEventListener('click', function (e) {
      if (window.innerWidth <= 920) return;
      e.preventDefault();
      var li = btn.closest('.has-sub');
      var open = li.classList.toggle('open');
      btn.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
  });
  document.addEventListener('click', function (e) {
    document.querySelectorAll('.nav .has-sub.open').forEach(function (li) {
      if (!li.contains(e.target)) {
        li.classList.remove('open');
        var b = li.querySelector('.nav-parent');
        if (b) b.setAttribute('aria-expanded', 'false');
      }
    });
  });

  /* ---------- Footer year ---------- */
  document.querySelectorAll('[data-year]').forEach(function (el) {
    el.textContent = new Date().getFullYear();
  });

  /* ---------- Dates: no past check-in, check-out after check-in ---------- */
  function iso(d) {
    var m = String(d.getMonth() + 1).padStart(2, '0');
    var day = String(d.getDate()).padStart(2, '0');
    return d.getFullYear() + '-' + m + '-' + day;
  }
  var today = iso(new Date());
  document.querySelectorAll('input[type="date"]').forEach(function (inp) {
    inp.min = today;
  });
  document.querySelectorAll('form').forEach(function (form) {
    var cin = form.querySelector('[name="checkin"]');
    var cout = form.querySelector('[name="checkout"]');
    if (cin && cout) {
      cin.addEventListener('change', function () {
        if (!cin.value) return;
        var next = new Date(cin.value + 'T00:00:00');
        next.setDate(next.getDate() + 1);
        cout.min = iso(next);
        if (!cout.value || cout.value <= cin.value) cout.value = iso(next);
      });
    }
  });

  /* ---------- Prefill the booking form from the URL ---------- */
  var params = new URLSearchParams(window.location.search);
  var bookForm = document.querySelector('[data-prefill]');
  if (bookForm) {
    ['property', 'room', 'checkin', 'checkout', 'guests'].forEach(function (key) {
      var val = params.get(key);
      var field = bookForm.querySelector('[name="' + key + '"]');
      if (val && field) field.value = val;
    });
    var prop = bookForm.querySelector('[name="property"]');
    var room = bookForm.querySelector('[name="room"]');
    if (prop && room) {
      var syncRooms = function () {
        var p = prop.value;
        Array.prototype.forEach.call(room.options, function (o) {
          var g = o.getAttribute('data-property');
          o.hidden = !!(g && p && g !== p);
        });
        var cur = room.options[room.selectedIndex];
        if (cur && cur.hidden) room.value = '';
      };
      prop.addEventListener('change', syncRooms);
      syncRooms();
      if (params.get('room')) room.value = params.get('room');
    }
    if (params.get('property') || params.get('room')) {
      var target = document.getElementById('enquiry');
      if (target) setTimeout(function () { target.scrollIntoView(); }, 50);
    }
  }

  /* ---------- Demo forms: show a thank-you, send nothing ---------- */
  document.querySelectorAll('form[data-demo]').forEach(function (form) {
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      if (form.hasAttribute('data-go')) {
        // Quick booking bar: carry the details to the booking page
        var q = new URLSearchParams(new FormData(form)).toString();
        window.location.href = form.getAttribute('data-go') + '?' + q;
        return;
      }
      var success = document.getElementById(form.getAttribute('data-success'));
      if (success) {
        form.classList.add('is-sent');
        success.classList.add('show');
        success.setAttribute('tabindex', '-1');
        success.focus();
      }
    });
  });
  document.querySelectorAll('[data-reset-form]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var form = document.getElementById(btn.getAttribute('data-reset-form'));
      var box = btn.closest('.form-success');
      if (form) { form.reset(); form.classList.remove('is-sent'); }
      if (box) box.classList.remove('show');
    });
  });

  /* ---------- Gallery filter ---------- */
  var filterBtns = document.querySelectorAll('.filter-btn');
  var items = document.querySelectorAll('.masonry figure');
  var countEl = document.querySelector('[data-count]');
  function applyFilter(f) {
    var shown = 0;
    items.forEach(function (it) {
      var cats = (it.getAttribute('data-cat') || '').split(' ');
      var show = f === 'all' || cats.indexOf(f) > -1;
      it.hidden = !show;
      if (show) shown++;
    });
    filterBtns.forEach(function (b) {
      b.setAttribute('aria-pressed', b.getAttribute('data-filter') === f ? 'true' : 'false');
    });
    if (countEl) countEl.textContent = shown + (shown === 1 ? ' photo' : ' photos');
  }
  filterBtns.forEach(function (b) {
    b.addEventListener('click', function () { applyFilter(b.getAttribute('data-filter')); });
  });
  if (filterBtns.length) {
    var start = params.get('show');
    applyFilter(start && document.querySelector('.filter-btn[data-filter="' + start + '"]') ? start : 'all');
  }

  /* ---------- Lightbox ---------- */
  var links = Array.prototype.slice.call(document.querySelectorAll('a[data-lightbox]'));
  if (links.length) {
    var lb = document.createElement('div');
    lb.className = 'lightbox';
    lb.setAttribute('role', 'dialog');
    lb.setAttribute('aria-modal', 'true');
    lb.setAttribute('aria-label', 'Photo viewer');
    lb.innerHTML =
      '<figure><img alt=""><figcaption></figcaption></figure>' +
      '<button type="button" class="lb-btn lb-close" aria-label="Close"><svg class="icon"><use href="assets/icons.svg#close"/></svg></button>' +
      '<button type="button" class="lb-btn lb-prev" aria-label="Previous photo"><svg class="icon"><use href="assets/icons.svg#chev-left"/></svg></button>' +
      '<button type="button" class="lb-btn lb-next" aria-label="Next photo"><svg class="icon"><use href="assets/icons.svg#chev-right"/></svg></button>';
    document.body.appendChild(lb);
    var img = lb.querySelector('img');
    var cap = lb.querySelector('figcaption');
    var group = [];
    var idx = 0;
    var lastFocus = null;

    function visible(a) {
      var fig = a.closest('figure');
      return !(fig && fig.hidden);
    }
    function show(i) {
      idx = (i + group.length) % group.length;
      var a = group[idx];
      var thumb = a.querySelector('img');
      img.src = a.getAttribute('href');
      img.alt = thumb ? thumb.alt : '';
      cap.textContent = a.getAttribute('data-caption') || (thumb ? thumb.alt : '');
    }
    function open(a) {
      var name = a.getAttribute('data-lightbox');
      group = links.filter(function (l) { return l.getAttribute('data-lightbox') === name && visible(l); });
      lastFocus = a;
      show(group.indexOf(a));
      lb.classList.add('open');
      document.body.style.overflow = 'hidden';
      lb.querySelector('.lb-close').focus();
    }
    function close() {
      lb.classList.remove('open');
      document.body.style.overflow = '';
      if (lastFocus) lastFocus.focus();
    }
    links.forEach(function (a) {
      a.addEventListener('click', function (e) { e.preventDefault(); open(a); });
    });
    lb.querySelector('.lb-close').addEventListener('click', close);
    lb.querySelector('.lb-prev').addEventListener('click', function () { show(idx - 1); });
    lb.querySelector('.lb-next').addEventListener('click', function () { show(idx + 1); });
    lb.addEventListener('click', function (e) { if (e.target === lb) close(); });
    lb.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') close();
      if (e.key === 'ArrowLeft') show(idx - 1);
      if (e.key === 'ArrowRight') show(idx + 1);
    });
  }
})();
