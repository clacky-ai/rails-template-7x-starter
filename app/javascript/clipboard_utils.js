// Simple Clipboard Utility
// Copy to clipboard with fallback support for iframe and older browsers

function copyToClipboard(text) {
  return new Promise((resolve, reject) => {
    // Try modern Clipboard API first
    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(text)
        .then(() => resolve(true))
        .catch(() => {
          // Fallback to execCommand
          fallbackCopy(text) ? resolve(true) : reject(new Error('Copy failed'));
        });
    } else {
      // Use execCommand for iframe and older browsers
      fallbackCopy(text) ? resolve(true) : reject(new Error('Copy failed'));
    }
  });
}

function fallbackCopy(text) {
  const textArea = document.createElement('textarea');
  textArea.value = text;
  textArea.style.position = 'fixed';
  textArea.style.opacity = '0';
  document.body.appendChild(textArea);
  textArea.select();
  
  try {
    const success = document.execCommand('copy');
    document.body.removeChild(textArea);
    return success;
  } catch (error) {
    document.body.removeChild(textArea);
    return false;
  }
}

// Export globally
window.copyToClipboard = copyToClipboard;
