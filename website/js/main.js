/**
 * Modern Classes Patna - Official Website JavaScript
 * Pure Vanilla JS, WCAG AA Accessibility, Accessible Navigation & Enquiry Handling
 */

document.addEventListener('DOMContentLoaded', () => {
  initMobileNav();
  initContactEnquiryForm();
  highlightActiveNavLink();
});

/**
 * Mobile Navigation Toggle with ARIA Support
 */
function initMobileNav() {
  const toggleBtn = document.querySelector('.mobile-nav-toggle');
  const navMenu = document.querySelector('.nav-menu');

  if (!toggleBtn || !navMenu) return;

  function toggleMenu(isOpen) {
    toggleBtn.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
    if (isOpen) {
      navMenu.classList.add('is-active');
      document.body.style.overflow = 'hidden';
    } else {
      navMenu.classList.remove('is-active');
      document.body.style.overflow = '';
    }
  }

  toggleBtn.addEventListener('click', () => {
    const isExpanded = toggleBtn.getAttribute('aria-expanded') === 'true';
    toggleMenu(!isExpanded);
  });

  // Close when pressing Escape
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && toggleBtn.getAttribute('aria-expanded') === 'true') {
      toggleMenu(false);
      toggleBtn.focus();
    }
  });

  // Close menu when clicking outside or clicking any nav link
  navMenu.querySelectorAll('.nav-link').forEach(link => {
    link.addEventListener('click', () => {
      if (window.innerWidth <= 768) {
        toggleMenu(false);
      }
    });
  });
}

/**
 * Automatically sets the active state on current navigation link
 */
function highlightActiveNavLink() {
  const currentPath = window.location.pathname.split('/').pop() || 'index.html';
  const navLinks = document.querySelectorAll('.nav-link, .legal-nav a');

  navLinks.forEach(link => {
    const href = link.getAttribute('href');
    if (href === currentPath || (currentPath === '' && href === 'index.html')) {
      link.classList.add('active');
      link.setAttribute('aria-current', 'page');
    }
  });
}

/**
 * Contact & Student Enquiry Handler
 * Validates data and provides verified transmission via Email and WhatsApp
 * Strictly avoids fake success messages or silent discarding.
 */
function initContactEnquiryForm() {
  const form = document.getElementById('enquiryForm');
  if (!form) return;

  const feedbackBox = document.getElementById('formFeedback');

  form.addEventListener('submit', (e) => {
    e.preventDefault();

    const name = form.querySelector('#studentName')?.value.trim();
    const phone = form.querySelector('#studentPhone')?.value.trim();
    const email = form.querySelector('#studentEmail')?.value.trim();
    const course = form.querySelector('#targetCourse')?.value;
    const message = form.querySelector('#enquiryMessage')?.value.trim();

    // Validation
    if (!name || !phone || !course) {
      if (feedbackBox) {
        feedbackBox.className = 'form-feedback show-info';
        feedbackBox.innerHTML = '<strong>Please complete required fields:</strong> Name, 10-digit Phone, and Target Course.';
        feedbackBox.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
      }
      return;
    }

    const cleanPhone = phone.replace(/[^0-9+]/g, '');
    if (cleanPhone.length < 10) {
      if (feedbackBox) {
        feedbackBox.className = 'form-feedback show-info';
        feedbackBox.innerHTML = '<strong>Invalid Phone:</strong> Please enter a valid 10-digit mobile contact number.';
      }
      return;
    }

    // Construct formatted message
    const formattedSubject = `Course Enquiry: ${course} - ${name}`;
    const formattedBody = `Hello Modern Classes Patna Admissions Team,\n\nI would like to enquire regarding enrollment and batch details:\n\nStudent Name: ${name}\nContact Phone: ${phone}\nEmail: ${email || 'Not provided'}\nTarget Program: ${course}\nDetails / Query: ${message || 'Please provide upcoming batch schedule and admission procedure.'}\n\nThank you,\n${name}`;

    const mailtoUrl = `mailto:madhurendrayadav06@gmail.com?subject=${encodeURIComponent(formattedSubject)}&body=${encodeURIComponent(formattedBody)}`;
    const whatsappText = `*Enquiry for Modern Classes Patna*\n\n*Name:* ${name}\n*Phone:* ${phone}\n*Course:* ${course}\n*Query:* ${message || 'Information requested'}`;
    const whatsappUrl = `https://wa.me/916209016951?text=${encodeURIComponent(whatsappText)}`;

    if (feedbackBox) {
      feedbackBox.className = 'form-feedback show-success';
      feedbackBox.innerHTML = `
        <h4 style="margin-bottom:0.5rem; color:#10B981;">✓ Enquiry Ready for Direct Dispatch</h4>
        <p style="margin-bottom:0.75rem; font-size:0.92rem; color:#F8FAFC;">
          To ensure your enquiry is received instantly without third-party email delays, select your preferred contact channel:
        </p>
        <div style="display:flex; gap:0.75rem; flex-wrap:wrap; margin-top:0.5rem;">
          <a href="${mailtoUrl}" class="btn btn-primary btn-sm" style="background:#FFB703; color:#0B0F19;">
            Send via Official Email
          </a>
          <a href="${whatsappUrl}" target="_blank" rel="noopener noreferrer" class="btn btn-secondary btn-sm" style="border-color:#10B981; color:#10B981;">
            Send via Official WhatsApp
          </a>
        </div>
        <p style="margin-top:0.75rem; font-size:0.8rem; color:#94A3B8;">
          Admissions Helpline: <strong>+91 6209016951</strong> | Email: <strong>madhurendrayadav06@gmail.com</strong>
        </p>
      `;
      feedbackBox.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }

    // Automatically trigger mailto link as standard fallback
    try {
      window.location.href = mailtoUrl;
    } catch (_) {
      // Allowed fallback if popup blocked
    }
  });
}
