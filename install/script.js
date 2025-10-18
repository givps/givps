// Theme Management
class ThemeManager {
    constructor() {
        this.themeToggle = document.getElementById('theme-toggle');
        this.themeIcon = this.themeToggle.querySelector('i');
        this.themeText = this.themeToggle.querySelector('.theme-text');
        this.currentTheme = localStorage.getItem('theme') || 'light';
        
        this.init();
    }
    
    init() {
        this.applyTheme(this.currentTheme);
        this.setupEventListeners();
    }
    
    setupEventListeners() {
        this.themeToggle.addEventListener('click', () => {
            this.toggleTheme();
        });
        
        // Add keyboard accessibility
        this.themeToggle.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' || e.key === ' ') {
                this.toggleTheme();
            }
        });
    }
    
    toggleTheme() {
        this.currentTheme = this.currentTheme === 'light' ? 'dark' : 'light';
        this.applyTheme(this.currentTheme);
        this.saveTheme();
        this.animateToggle();
    }
    
    applyTheme(theme) {
        document.documentElement.setAttribute('data-theme', theme);
        
        if (theme === 'dark') {
            this.themeIcon.className = 'fas fa-sun';
            this.themeText.textContent = 'Light Mode';
        } else {
            this.themeIcon.className = 'fas fa-moon';
            this.themeText.textContent = 'Dark Mode';
        }
    }
    
    saveTheme() {
        localStorage.setItem('theme', this.currentTheme);
    }
    
    animateToggle() {
        this.themeToggle.style.transform = 'scale(0.95)';
        setTimeout(() => {
            this.themeToggle.style.transform = 'scale(1)';
        }, 150);
    }
}

// Copy Command Manager
class CopyManager {
    constructor() {
        this.copyButtons = document.querySelectorAll('.copy-btn');
        this.toast = document.getElementById('copyToast');
        this.init();
    }
    
    init() {
        this.setupCopyButtons();
    }
    
    setupCopyButtons() {
        this.copyButtons.forEach(button => {
            button.addEventListener('click', (e) => {
                e.stopPropagation();
                const command = button.getAttribute('data-command');
                this.copyToClipboard(command);
                this.showToast();
                this.animateButton(button);
            });
        });
    }
    
    async copyToClipboard(text) {
        try {
            await navigator.clipboard.writeText(text);
        } catch (err) {
            // Fallback for older browsers
            const textArea = document.createElement('textarea');
            textArea.value = text;
            document.body.appendChild(textArea);
            textArea.select();
            document.execCommand('copy');
            document.body.removeChild(textArea);
        }
    }
    
    showToast() {
        this.toast.classList.add('show');
        setTimeout(() => {
            this.toast.classList.remove('show');
        }, 3000);
    }
    
    animateButton(button) {
        const originalHTML = button.innerHTML;
        button.innerHTML = '<i class="fas fa-check"></i> Copied!';
        button.style.background = 'var(--secondary-color)';
        
        setTimeout(() => {
            button.innerHTML = originalHTML;
            button.style.background = '';
        }, 2000);
    }
}

// Modal Manager
class ModalManager {
    constructor() {
        this.modal = document.getElementById('donateModal');
        this.init();
    }
    
    init() {
        this.setupEventListeners();
    }
    
    setupEventListeners() {
        // Close modal when clicking outside
        this.modal.addEventListener('click', (e) => {
            if (e.target === this.modal) {
                this.closeModal();
            }
        });
        
        // Close modal with Escape key
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.modal.style.display === 'block') {
                this.closeModal();
            }
        });
    }
    
    openModal() {
        this.modal.style.display = 'block';
        document.body.style.overflow = 'hidden';
    }
    
    closeModal() {
        this.modal.style.display = 'none';
        document.body.style.overflow = 'auto';
    }
}

// Navigation Manager
class NavigationManager {
    constructor() {
        this.navLinks = document.querySelectorAll('.nav-link');
        this.init();
    }
    
    init() {
        this.setupNavigation();
        this.setupActiveState();
    }
    
    setupNavigation() {
        this.navLinks.forEach(link => {
            link.addEventListener('click', (e) => {
                if (!link.href.includes('#')) {
                    e.preventDefault();
                    this.setActiveLink(link);
                    this.showLoadingState();
                    
                    // Simulate navigation delay
                    setTimeout(() => {
                        window.location.href = link.href;
                    }, 800);
                }
            });
        });
    }
    
    setActiveLink(activeLink) {
        this.navLinks.forEach(link => {
            link.classList.remove('active');
        });
        activeLink.classList.add('active');
    }
    
    showLoadingState() {
        const loader = document.createElement('div');
        loader.className = 'page-loader';
        loader.innerHTML = `
            <div class="loader-spinner"></div>
            <p>Loading...</p>
        `;
        document.body.appendChild(loader);
        
        // Add loader styles
        const style = document.createElement('style');
        style.textContent = `
            .page-loader {
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                background: var(--background-color);
                display: flex;
                flex-direction: column;
                justify-content: center;
                align-items: center;
                z-index: 9999;
            }
            .loader-spinner {
                width: 50px;
                height: 50px;
                border: 3px solid var(--border-color);
                border-top: 3px solid var(--primary-color);
                border-radius: 50%;
                animation: spin 1s linear infinite;
                margin-bottom: 1rem;
            }
            @keyframes spin {
                0% { transform: rotate(0deg); }
                100% { transform: rotate(360deg); }
            }
        `;
        document.head.appendChild(style);
    }
}

// Social Media Manager
class SocialMediaManager {
    constructor() {
        this.socialLinks = document.querySelectorAll('.social-link');
        this.init();
    }
    
    init() {
        this.setupSocialInteractions();
    }
    
    setupSocialInteractions() {
        this.socialLinks.forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                this.animateSocialClick(link);
                
                // Open in new tab after animation
                setTimeout(() => {
                    window.open(link.href, '_blank');
                }, 300);
            });
        });
    }
    
    animateSocialClick(link) {
        link.style.transform = 'scale(0.8)';
        setTimeout(() => {
            link.style.transform = 'scale(1.1)';
        }, 150);
        setTimeout(() => {
            link.style.transform = 'scale(1)';
        }, 300);
    }
}

// Background Animation
class BackgroundAnimation {
    constructor() {
        this.background = document.querySelector('.background-animation');
        this.init();
    }
    
    init() {
        this.createParticles();
    }
    
    createParticles() {
        const particlesContainer = document.createElement('div');
        particlesContainer.className = 'particles-container';
        particlesContainer.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            pointer-events: none;
            z-index: -1;
        `;
        
        for (let i = 0; i < 20; i++) {
            const particle = document.createElement('div');
            particle.style.cssText = `
                position: absolute;
                width: 4px;
                height: 4px;
                background: var(--primary-color);
                border-radius: 50%;
                opacity: 0.3;
                animation: float 15s infinite linear;
                animation-delay: ${Math.random() * 15}s;
            `;
            
            particle.style.left = `${Math.random() * 100}%`;
            particle.style.top = `${Math.random() * 100}%`;
            
            particlesContainer.appendChild(particle);
        }
        
        // Add animation keyframes
        const style = document.createElement('style');
        style.textContent = `
            @keyframes float {
                0%, 100% {
                    transform: translate(0, 0) rotate(0deg);
                }
                25% {
                    transform: translate(100px, 100px) rotate(90deg);
                }
                50% {
                    transform: translate(0, 200px) rotate(180deg);
                }
                75% {
                    transform: translate(-100px, 100px) rotate(270deg);
                }
            }
        `;
        document.head.appendChild(style);
        
        this.background.appendChild(particlesContainer);
    }
}

// Main Application
class App {
    constructor() {
        this.themeManager = new ThemeManager();
        this.copyManager = new CopyManager();
        this.modalManager = new ModalManager();
        this.navManager = new NavigationManager();
        this.socialManager = new SocialMediaManager();
        this.backgroundAnimation = new BackgroundAnimation();
        
        this.init();
    }
    
    init() {
        this.setupPageLoad();
        this.setupIntersectionObserver();
        this.setupCommandBoxInteractions();
    }
    
    setupPageLoad() {
        // Add loading animation
        document.body.style.opacity = '0';
        document.body.style.transition = 'opacity 0.5s ease';
        
        window.addEventListener('load', () => {
            setTimeout(() => {
                document.body.style.opacity = '1';
            }, 100);
        });
    }
    
    setupIntersectionObserver() {
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.style.animationPlayState = 'running';
                }
            });
        }, { threshold: 0.1 });
        
        // Observe animated elements
        document.querySelectorAll('.version-card, .support-card, .notes-section').forEach(el => {
            observer.observe(el);
        });
    }
    
    setupCommandBoxInteractions() {
        const commandBoxes = document.querySelectorAll('.command-box');
        commandBoxes.forEach(box => {
            box.addEventListener('click', (e) => {
                if (!e.target.closest('.copy-btn')) {
                    const copyBtn = box.querySelector('.copy-btn');
                    const command = copyBtn.getAttribute('data-command');
                    this.copyManager.copyToClipboard(command);
                    this.copyManager.showToast();
                    this.copyManager.animateButton(copyBtn);
                }
            });
        });
    }
}

// Global functions for modal
function showDonateModal() {
    const modalManager = new ModalManager();
    modalManager.openModal();
}

function closeDonateModal() {
    const modalManager = new ModalManager();
    modalManager.closeModal();
}

// Initialize the application
document.addEventListener('DOMContentLoaded', () => {
    new App();
});

// Utility functions
const utils = {
    debounce: (func, wait) => {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }
};

// Export for potential future use
window.utils = utils;
