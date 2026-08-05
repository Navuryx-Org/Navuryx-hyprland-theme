(() => {
  const navToggle = document.querySelector('[data-nav-toggle]');
  const navLinks = document.querySelector('[data-nav-links]');
  navToggle?.addEventListener('click', () => {
    const open = navLinks.classList.toggle('open');
    navToggle.setAttribute('aria-expanded', String(open));
  });

  document.querySelectorAll('[data-copy]').forEach((button) => {
    button.addEventListener('click', async () => {
      const target = document.querySelector(button.dataset.copy);
      if (!target) return;
      const text = target.innerText || target.textContent || '';
      await navigator.clipboard.writeText(text.trim());
      const old = button.textContent;
      button.textContent = 'Copied';
      setTimeout(() => { button.textContent = old; }, 1200);
    });
  });

  const builder = document.querySelector('[data-install-builder]');
  if (builder) {
    const output = document.querySelector('#generated-command');
    const update = () => {
      const args = [];
      if (builder.querySelector('[name="flatpak"]')?.checked) args.push('--with-flatpak');
      if (builder.querySelector('[name="paru"]')?.checked) args.push('--with-paru');
      if (builder.querySelector('[name="yes"]')?.checked) args.push('--yes');
      output.textContent = [
        'git clone https://github.com/navuryx-org/navuryx-hyprland-theme.git',
        'cd navuryx-hyprland-theme',
        'chmod +x install.sh uninstall.sh navuryx',
        `./install.sh${args.length ? ` ${args.join(' ')}` : ''}`
      ].join('\n');
    };
    builder.addEventListener('change', update);
    update();
  }
})();
