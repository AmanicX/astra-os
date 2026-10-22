/* ═══════════════════════════════════════════════════════════
   AstraOS Website — Animations & Interactivity
   ═══════════════════════════════════════════════════════════ */

(function () {
  'use strict';

  /* ── STARFIELD CANVAS ─────────────────────────────────── */
  const canvas = document.getElementById('starfield');
  const ctx = canvas.getContext('2d');
  let stars = [];
  let shootingStars = [];
  let animFrame;
  let mouseX = 0, mouseY = 0;

  function resizeCanvas() {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
  }

  function createStars(count) {
    stars = [];
    for (let i = 0; i < count; i++) {
      stars.push({
        x: Math.random() * canvas.width,
        y: Math.random() * canvas.height,
        radius: Math.random() * 1.5 + 0.3,
        opacity: Math.random() * 0.6 + 0.1,
        twinkleSpeed: Math.random() * 0.02 + 0.005,
        twinklePhase: Math.random() * Math.PI * 2,
        // Parallax depth (0 = far, 1 = close)
        depth: Math.random(),
      });
    }
  }

  function spawnShootingStar() {
    if (shootingStars.length > 2) return;
    const startX = Math.random() * canvas.width;
    const startY = Math.random() * canvas.height * 0.4;
    const angle = Math.PI / 4 + Math.random() * Math.PI / 6;
    shootingStars.push({
      x: startX,
      y: startY,
      length: 60 + Math.random() * 80,
      speed: 6 + Math.random() * 4,
      angle,
      opacity: 1,
      life: 1,
    });
  }

  function drawStars(time) {
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Parallax offset from mouse
    const cx = canvas.width / 2;
    const cy = canvas.height / 2;
    const offsetX = (mouseX - cx) / cx;
    const offsetY = (mouseY - cy) / cy;

    // Draw stars
    for (const star of stars) {
      const twinkle = Math.sin(time * star.twinkleSpeed + star.twinklePhase);
      const opacity = star.opacity * (0.6 + 0.4 * twinkle);

      // Parallax movement
      const px = star.x + offsetX * star.depth * 15;
      const py = star.y + offsetY * star.depth * 15;

      ctx.beginPath();
      ctx.arc(px, py, star.radius, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(232, 238, 247, ${opacity})`;
      ctx.fill();

      // Add a subtle cyan tint to some stars
      if (star.depth > 0.8) {
        ctx.beginPath();
        ctx.arc(px, py, star.radius * 2.5, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(103, 232, 249, ${opacity * 0.08})`;
        ctx.fill();
      }
    }

    // Draw shooting stars
    for (let i = shootingStars.length - 1; i >= 0; i--) {
      const s = shootingStars[i];
      s.x += Math.cos(s.angle) * s.speed;
      s.y += Math.sin(s.angle) * s.speed;
      s.life -= 0.015;
      s.opacity = s.life;

      if (s.life <= 0) {
        shootingStars.splice(i, 1);
        continue;
      }

      const tailX = s.x - Math.cos(s.angle) * s.length;
      const tailY = s.y - Math.sin(s.angle) * s.length;

      const gradient = ctx.createLinearGradient(tailX, tailY, s.x, s.y);
      gradient.addColorStop(0, `rgba(103, 232, 249, 0)`);
      gradient.addColorStop(0.6, `rgba(103, 232, 249, ${s.opacity * 0.3})`);
      gradient.addColorStop(1, `rgba(232, 238, 247, ${s.opacity * 0.8})`);

      ctx.beginPath();
      ctx.moveTo(tailX, tailY);
      ctx.lineTo(s.x, s.y);
      ctx.strokeStyle = gradient;
      ctx.lineWidth = 1.5;
      ctx.stroke();

      // Head glow
      ctx.beginPath();
      ctx.arc(s.x, s.y, 2, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(232, 238, 247, ${s.opacity})`;
      ctx.fill();
    }
  }

  let lastTime = 0;
  function animateStars(timestamp) {
    drawStars(timestamp);
    animFrame = requestAnimationFrame(animateStars);
  }

  // Spawn shooting stars randomly
  setInterval(() => {
    if (Math.random() < 0.3) spawnShootingStar();
  }, 3000);

  resizeCanvas();
  createStars(Math.min(200, Math.floor(window.innerWidth * 0.12)));
  animateStars(0);

  window.addEventListener('resize', () => {
    resizeCanvas();
    createStars(Math.min(200, Math.floor(window.innerWidth * 0.12)));
  });

  /* ── CURSOR GLOW ──────────────────────────────────────── */
  const cursorGlow = document.getElementById('cursorGlow');
  let glowX = 0, glowY = 0, currentGlowX = 0, currentGlowY = 0;
  let isMouseOnPage = false;

  document.addEventListener('mousemove', (e) => {
    glowX = e.clientX;
    glowY = e.clientY;
    mouseX = e.clientX;
    mouseY = e.clientY;
    if (!isMouseOnPage) {
      isMouseOnPage = true;
      cursorGlow.classList.add('active');
    }
  });

  document.addEventListener('mouseleave', () => {
    isMouseOnPage = false;
    cursorGlow.classList.remove('active');
  });

  function updateGlow() {
    currentGlowX += (glowX - currentGlowX) * 0.08;
    currentGlowY += (glowY - currentGlowY) * 0.08;
    cursorGlow.style.transform = `translate(${currentGlowX - 300}px, ${currentGlowY - 300}px)`;
    requestAnimationFrame(updateGlow);
  }
  updateGlow();

  /* ── NAVIGATION ───────────────────────────────────────── */
  const nav = document.getElementById('nav');
  const burger = document.getElementById('navBurger');
  const mobileMenu = document.getElementById('mobileMenu');

  // Scroll detection for nav background
  let lastScroll = 0;
  window.addEventListener('scroll', () => {
    const scrollY = window.scrollY;
    if (scrollY > 50) {
      nav.classList.add('scrolled');
    } else {
      nav.classList.remove('scrolled');
    }
    lastScroll = scrollY;
  }, { passive: true });

  // Mobile menu toggle
  burger.addEventListener('click', () => {
    burger.classList.toggle('active');
    mobileMenu.classList.toggle('open');
  });

  // Close mobile menu on link click
  mobileMenu.querySelectorAll('.mobile-menu__link').forEach(link => {
    link.addEventListener('click', () => {
      burger.classList.remove('active');
      mobileMenu.classList.remove('open');
    });
  });

  /* ── SCROLL ANIMATIONS (Intersection Observer) ────────── */
  const animatedElements = document.querySelectorAll('[data-animate]');

  const observerOptions = {
    root: null,
    rootMargin: '300px 0px 300px 0px',
    threshold: 0.01,
  };

  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        const el = entry.target;
        const delay = parseInt(el.dataset.delay || '0', 10);
        if (delay > 0) {
          setTimeout(() => {
            el.classList.add('visible');
          }, delay);
        } else {
          el.classList.add('visible');
        }
        observer.unobserve(el);
      }
    });
  }, observerOptions);

  animatedElements.forEach((el) => observer.observe(el));

  // Safeguard: Ensure elements scroll smoothly into view
  function checkVisible() {
    animatedElements.forEach((el) => {
      const rect = el.getBoundingClientRect();
      if (rect.top < window.innerHeight + 600) {
        el.classList.add('visible');
      }
    });
  }
  checkVisible();
  window.addEventListener('scroll', checkVisible, { passive: true });

  /* ── SMOOTH SCROLL FOR ANCHOR LINKS ───────────────────── */
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
      const target = document.querySelector(this.getAttribute('href'));
      if (target) {
        e.preventDefault();
        const offset = 80;
        const top = target.getBoundingClientRect().top + window.scrollY - offset;
        window.scrollTo({ top, behavior: 'smooth' });
      }
    });
  });

  /* ── FEATURE CARD TILT EFFECT ─────────────────────────── */
  document.querySelectorAll('.feature-card').forEach(card => {
    card.addEventListener('mousemove', (e) => {
      const rect = card.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      const centerX = rect.width / 2;
      const centerY = rect.height / 2;
      const rotateX = (y - centerY) / centerY * -3;
      const rotateY = (x - centerX) / centerX * 3;

      card.style.transform = `translateY(-4px) perspective(600px) rotateX(${rotateX}deg) rotateY(${rotateY}deg)`;
    });

    card.addEventListener('mouseleave', () => {
      card.style.transform = '';
    });
  });

  /* ── GALLERY ITEM HOVER GLOW ──────────────────────────── */
  document.querySelectorAll('.gallery__item').forEach(item => {
    item.addEventListener('mousemove', (e) => {
      const rect = item.getBoundingClientRect();
      const x = ((e.clientX - rect.left) / rect.width) * 100;
      const y = ((e.clientY - rect.top) / rect.height) * 100;
      item.style.background = `radial-gradient(circle at ${x}% ${y}%, rgba(103, 232, 249, 0.04), rgba(14, 22, 40, 0.6) 60%)`;
    });

    item.addEventListener('mouseleave', () => {
      item.style.background = '';
    });
  });

  /* ── MAGNETIC BUTTONS ─────────────────────────────────── */
  document.querySelectorAll('.btn').forEach(btn => {
    btn.addEventListener('mousemove', (e) => {
      const rect = btn.getBoundingClientRect();
      const x = e.clientX - rect.left - rect.width / 2;
      const y = e.clientY - rect.top - rect.height / 2;
      btn.style.transform = `translateY(-2px) translate(${x * 0.15}px, ${y * 0.15}px)`;
    });

    btn.addEventListener('mouseleave', () => {
      btn.style.transform = '';
    });
  });

  /* ── HERO PARALLAX ON SCROLL ──────────────────────────── */
  const heroContent = document.querySelector('.hero__content');
  const heroRings = document.querySelector('.hero__bg-rings');

  window.addEventListener('scroll', () => {
    if (window.innerWidth <= 768) return;
    const scrollY = window.scrollY;
    const heroHeight = window.innerHeight;

    if (scrollY <= heroHeight) {
      const progress = scrollY / heroHeight;
      heroContent.style.transform = `translateY(${scrollY * 0.25}px)`;
      heroContent.style.opacity = Math.max(0, 1 - progress * 1.2);
      if (heroRings) {
        heroRings.style.transform = `translateY(${scrollY * 0.1}px) scale(${1 + progress * 0.08})`;
      }
    } else {
      heroContent.style.opacity = '0';
    }
  }, { passive: true });

  /* ── STACKED TABLE ROW REVEAL ─────────────────────────── */
  document.querySelectorAll('.stack__row').forEach((row, i) => {
    row.style.transitionDelay = `${i * 60}ms`;
  });

  /* ── CONSTELLATION CONNECTIONS (subtle) ───────────────── */
  // Draw faint lines between nearby stars on canvas for constellation effect
  function drawConstellations() {
    const connectionDistance = 100;
    ctx.save();
    for (let i = 0; i < stars.length; i++) {
      for (let j = i + 1; j < stars.length; j++) {
        const dx = stars[i].x - stars[j].x;
        const dy = stars[i].y - stars[j].y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < connectionDistance && stars[i].depth > 0.7 && stars[j].depth > 0.7) {
          const opacity = (1 - dist / connectionDistance) * 0.04;
          ctx.beginPath();
          ctx.moveTo(stars[i].x, stars[i].y);
          ctx.lineTo(stars[j].x, stars[j].y);
          ctx.strokeStyle = `rgba(103, 232, 249, ${opacity})`;
          ctx.lineWidth = 0.5;
          ctx.stroke();
        }
      }
    }
    ctx.restore();
  }

  // Override drawStars to include constellations
  const originalDrawStars = drawStars;
  // We integrate constellation drawing into the main animation loop
  // by patching the animation function
  function animateStarsWithConstellations(timestamp) {
    drawStars(timestamp);
    drawConstellations();
    requestAnimationFrame(animateStarsWithConstellations);
  }

  // Cancel original loop and start enhanced one
  cancelAnimationFrame(animFrame);
  animateStarsWithConstellations(0);

  /* ── TYPED EFFECT FOR SECTION TAGS ────────────────────── */
  // (Optional subtle effect - tags appear letter by letter when they enter view)

  /* ── INTERACTIVE KEYBOARD LISTENER ─────────────────────── */
  const keyMap = {
    'Meta': 'Super',
    'OS': 'Super',
    'Enter': 'Return',
    ' ': 'Space',
    'Shift': 'Shift',
    'Alt': 'Alt',
    'b': 'B',
    'B': 'B',
    's': 'S',
    'S': 'S',
    'l': 'L',
    'L': 'L',
    'q': 'Q',
    'Q': 'Q',
    'ArrowLeft': '←',
    'ArrowRight': '→',
    '/': '/',
  };

  const kbds = document.querySelectorAll('.keybind kbd');

  window.addEventListener('keydown', (e) => {
    const key = keyMap[e.key] || e.key;
    kbds.forEach(kbd => {
      const txt = kbd.textContent.trim();
      if (txt === key || (key === 'Super' && txt.toLowerCase().includes('super'))) {
        kbd.classList.add('active');
      }
    });
  });

  window.addEventListener('keyup', (e) => {
    const key = keyMap[e.key] || e.key;
    kbds.forEach(kbd => {
      const txt = kbd.textContent.trim();
      if (txt === key || (key === 'Super' && txt.toLowerCase().includes('super'))) {
        kbd.classList.remove('active');
      }
    });
  });

  /* ── CLICK TO COPY CODE SNIPPETS ──────────────────────── */
  document.querySelectorAll('.install__step code, .presets__cli code').forEach(code => {
    code.style.cursor = 'pointer';
    code.title = 'Click to copy';
    code.addEventListener('click', () => {
      const text = code.innerText.replace(/^\$\s*/, '');
      navigator.clipboard.writeText(text).then(() => {
        const original = code.innerHTML;
        code.innerHTML = '<span style="color:#67e8f9">✓ Copied!</span>';
        setTimeout(() => { code.innerHTML = original; }, 1800);
      }).catch(() => {});
    });
  });

  /* ── PRELOADER PROTECTION ─────────────────────────────── */
  window.addEventListener('load', () => {
    document.body.style.opacity = '1';
  });

  console.log(
    '%c✦ AstraOS %c— Astral Meridian',
    'color: #67E8F9; font-size: 16px; font-weight: 700;',
    'color: #6B7A90; font-size: 16px; font-weight: 300;'
  );
})();
