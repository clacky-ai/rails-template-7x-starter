import './base'

document.addEventListener('DOMContentLoaded', () => {
  const themeToggle = document.getElementById('theme-toggle');
  const lightIcon = document.getElementById('theme-toggle-light-icon');
  const darkIcon = document.getElementById('theme-toggle-dark-icon');
  
  if (!themeToggle || !lightIcon || !darkIcon) return;

  const isDarkKey = 'admin-isdark';
  const savedIsDark = JSON.parse(localStorage.getItem(isDarkKey) || 'false');

  // Initialize theme and icons
  function updateTheme(isDark) {
    if (isDark) {
      document.documentElement.classList.add('dark');
      lightIcon.classList.add('hidden');
      darkIcon.classList.remove('hidden');
    } else {
      document.documentElement.classList.remove('dark');
      lightIcon.classList.remove('hidden');
      darkIcon.classList.add('hidden');
    }
  }

  // Set initial state
  updateTheme(savedIsDark);

  // Handle theme toggle
  themeToggle.addEventListener('click', () => {
    const isDark = document.documentElement.classList.contains('dark');
    const newIsDark = !isDark;
    
    localStorage.setItem(isDarkKey, JSON.stringify(newIsDark));
    updateTheme(newIsDark);
  });
});
