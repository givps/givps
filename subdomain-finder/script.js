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

// Subdomain Scanner
class SubdomainScanner {
    constructor() {
        this.domainInput = document.getElementById('domainInput');
        this.searchBtn = document.getElementById('searchBtn');
        this.resultsSection = document.getElementById('resultsSection');
        this.loadingSection = document.getElementById('loadingSection');
        this.resultsBody = document.getElementById('resultsBody');
        this.totalSubdomains = document.getElementById('totalSubdomains');
        this.activeSubdomains = document.getElementById('activeSubdomains');
        this.scanTime = document.getElementById('scanTime');
        this.exportBtn = document.getElementById('exportBtn');
        this.clearBtn = document.getElementById('clearBtn');
        this.progressFill = document.getElementById('progressFill');
        this.currentScan = document.getElementById('currentScan');
        
        this.deepScan = document.getElementById('deepScan');
        this.checkHttp = document.getElementById('checkHttp');
        
        this.scanResults = [];
        this.scanStartTime = null;
        this.isScanning = false;
        
        this.init();
    }
    
    init() {
        this.setupEventListeners();
        this.loadSampleData(); // For demonstration
    }
    
    setupEventListeners() {
        this.searchBtn.addEventListener('click', () => {
            this.startScan();
        });
        
        this.domainInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.startScan();
            }
        });
        
        this.exportBtn.addEventListener('click', () => {
            this.exportResults();
        });
        
        this.clearBtn.addEventListener('click', () => {
            this.clearResults();
        });
        
        // Input validation
        this.domainInput.addEventListener('input', (e) => {
            this.validateDomainInput(e.target.value);
        });
    }
    
    validateDomainInput(value) {
        const domainRegex = /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+$/;
        const isValid = domainRegex.test(value) || value === '';
        
        if (value && !isValid) {
            this.domainInput.style.borderColor = 'var(--warning-color)';
        } else {
            this.domainInput.style.borderColor = 'var(--border-color)';
        }
        
        return isValid;
    }
    
    async startScan() {
        const domain = this.domainInput.value.trim();
        
        if (!domain) {
            this.showError('Please enter a domain name');
            return;
        }
        
        if (!this.validateDomainInput(domain)) {
            this.showError('Please enter a valid domain name');
            return;
        }
        
        this.isScanning = true;
        this.scanResults = [];
        this.scanStartTime = Date.now();
        
        this.showLoading();
        this.updateProgress(0);
        
        try {
            // Simulate scanning process with multiple data sources
            await this.scanWithSource('DNS Enumeration', 20);
            await this.scanWithSource('Certificate Transparency', 40);
            await this.scanWithSource('Search Engines', 60);
            
            if (this.deepScan.checked) {
                await this.scanWithSource('Brute Force', 80);
                await this.scanWithSource('Web Archives', 95);
            }
            
            await this.scanWithSource('Finalizing', 100);
            
            this.completeScan();
        } catch (error) {
            this.showError('Scan failed: ' + error.message);
            this.hideLoading();
        }
    }
    
    async scanWithSource(sourceName, progress) {
        this.currentScan.textContent = `Scanning: ${sourceName}`;
        this.updateProgress(progress);
        
        // Simulate API call delay
        await new Promise(resolve => setTimeout(resolve, 1000 + Math.random() * 2000));
        
        // Generate mock subdomains based on the source
        const mockSubdomains = this.generateMockSubdomains(sourceName);
        this.scanResults.push(...mockSubdomains);
        
        // Update UI with new results
        this.updateResultsTable();
        this.updateStats();
    }
    
    generateMockSubdomains(source) {
        const domain = this.domainInput.value.trim();
        const baseSubdomains = [
            'www', 'mail', 'ftp', 'localhost', 'webmail', 'smtp', 'pop', 'imap',
            'blog', 'news', 'shop', 'store', 'api', 'dev', 'test', 'staging',
            'secure', 'login', 'admin', 'dashboard', 'cpanel', 'whm', 'webdisk',
            'ns1', 'ns2', 'dns1', 'dns2', 'cdn', 'static', 'img', 'images',
            'assets', 'media', 'uploads', 'download', 'files', 'docs', 'support',
            'help', 'forum', 'community', 'chat', 'live', 'status', 'monitor'
        ];
        
        const additionalSubdomains = [
            'app', 'apps', 'mobile', 'm', 'portal', 'gateway', 'proxy',
            'vpn', 'remote', 'access', 'secure', 'auth', 'oauth',
            'backup', 'archive', 'old', 'new', 'temp', 'tmp'
        ];
        
        let subdomains = [...baseSubdomains];
        
        if (this.deepScan.checked) {
            subdomains = [...subdomains, ...additionalSubdomains];
        }
        
        // Shuffle and take a random sample
        const shuffled = subdomains.sort(() => 0.5 - Math.random());
        const sampleSize = this.deepScan.checked ? 
            Math.floor(Math.random() * 10) + 15 : 
            Math.floor(Math.random() * 8) + 8;
        
        const selected = shuffled.slice(0, sampleSize);
        
        return selected.map(subdomain => {
            const fullSubdomain = `${subdomain}.${domain}`;
            const isActive = Math.random() > 0.3; // 70% chance of being active
            
            return {
                subdomain: fullSubdomain,
                ip: this.generateRandomIP(),
                status: isActive ? this.getRandomStatus() : 0,
                responseTime: isActive ? (Math.random() * 500 + 50).toFixed(0) : 0,
                source: source
            };
        });
    }
    
    generateRandomIP() {
        return `${Math.floor(Math.random() * 255)}.${Math.floor(Math.random() * 255)}.${Math.floor(Math.random() * 255)}.${Math.floor(Math.random() * 255)}`;
    }
    
    getRandomStatus() {
        const statuses = [200, 200, 200, 200, 301, 302, 403, 404, 500];
        return statuses[Math.floor(Math.random() * statuses.length)];
    }
    
    updateProgress(percentage) {
        this.progressFill.style.width = `${percentage}%`;
    }
    
    updateResultsTable() {
        // Remove duplicates based on subdomain
        const uniqueResults = this.scanResults.reduce((acc, current) => {
            if (!acc.find(item => item.subdomain === current.subdomain)) {
                acc.push(current);
            }
            return acc;
        }, []);
        
        this.resultsBody.innerHTML = '';
        
        uniqueResults.forEach(result => {
            const row = document.createElement('tr');
            
            const statusClass = result.status >= 200 && result.status < 300 ? 'status-success' :
                              result.status >= 300 && result.status < 400 ? 'status-warning' :
                              result.status >= 400 ? 'status-error' : 'status-error';
            
            const statusText = result.status === 0 ? 'Inactive' : `HTTP ${result.status}`;
            const responseTime = result.status === 0 ? 'N/A' : `${result.responseTime}ms`;
            
            row.innerHTML = `
                <td>
                    <strong>${result.subdomain}</strong>
                    <div style="font-size: 0.875rem; color: var(--text-secondary); margin-top: 0.25rem;">
                        Source: ${result.source}
                    </div>
                </td>
                <td>${result.ip}</td>
                <td>
                    <span class="status-badge ${statusClass}">${statusText}</span>
                </td>
                <td>${responseTime}</td>
                <td>
                    <button class="view-btn" onclick="subdomainScanner.viewSubdomain('${result.subdomain}')">
                        <i class="fas fa-external-link-alt"></i>
                        View
                    </button>
                </td>
            `;
            
            this.resultsBody.appendChild(row);
        });
    }
    
    updateStats() {
        const uniqueResults = this.scanResults.reduce((acc, current) => {
            if (!acc.find(item => item.subdomain === current.subdomain)) {
                acc.push(current);
            }
            return acc;
        }, []);
        
        const activeCount = uniqueResults.filter(result => result.status !== 0).length;
        const totalCount = uniqueResults.length;
        
        this.totalSubdomains.textContent = totalCount;
        this.activeSubdomains.textContent = activeCount;
        
        if (this.scanStartTime) {
            const duration = ((Date.now() - this.scanStartTime) / 1000).toFixed(1);
            this.scanTime.textContent = `${duration}s`;
        }
    }
    
    completeScan() {
        this.isScanning = false;
        this.hideLoading();
        this.showResults();
        
        // Show completion message
        this.showNotification('Scan completed successfully!', 'success');
    }
    
    showLoading() {
        this.searchBtn.disabled = true;
        this.searchBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Scanning...';
        this.loadingSection.style.display = 'block';
        this.resultsSection.style.display = 'block';
    }
    
    hideLoading() {
        this.searchBtn.disabled = false;
        this.searchBtn.innerHTML = '<i class="fas fa-search"></i> Find Subdomains';
        this.loadingSection.style.display = 'none';
    }
    
    showResults() {
        this.resultsSection.style.display = 'block';
    }
    
    viewSubdomain(subdomain) {
        const protocol = this.checkHttp.checked ? 'http' : 'https';
        const url = `${protocol}://${subdomain}`;
        window.open(url, '_blank');
    }
    
    exportResults() {
        if (this.scanResults.length === 0) {
            this.showError('No results to export');
            return;
        }
        
        const uniqueResults = this.scanResults.reduce((acc, current) => {
            if (!acc.find(item => item.subdomain === current.subdomain)) {
                acc.push(current);
            }
            return acc;
        }, []);
        
        const csvContent = this.convertToCSV(uniqueResults);
        const blob = new Blob([csvContent], { type: 'text/csv' });
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        
        const domain = this.domainInput.value.trim() || 'subdomains';
        a.setAttribute('href', url);
        a.setAttribute('download', `${domain}-subdomains-${new Date().getTime()}.csv`);
        a.click();
        
        window.URL.revokeObjectURL(url);
        this.showNotification('Results exported successfully!', 'success');
    }
    
    convertToCSV(results) {
        const headers = ['Subdomain', 'IP Address', 'HTTP Status', 'Response Time', 'Source'];
        const csvRows = [headers.join(',')];
        
        results.forEach(result => {
            const row = [
                result.subdomain,
                result.ip,
                result.status,
                result.responseTime,
                result.source
            ];
            csvRows.push(row.join(','));
        });
        
        return csvRows.join('\n');
    }
    
    clearResults() {
        this.scanResults = [];
        this.resultsBody.innerHTML = '';
        this.updateStats();
        this.resultsSection.style.display = 'none';
        this.showNotification('Results cleared', 'info');
    }
    
    showError(message) {
        this.showNotification(message, 'error');
    }
    
    showNotification(message, type = 'info') {
        // Remove existing notifications
        const existingNotifications = document.querySelectorAll('.notification');
        existingNotifications.forEach(notification => notification.remove());
        
        const notification = document.createElement('div');
        notification.className = `notification notification-${type}`;
        notification.innerHTML = `
            <div class="notification-content">
                <i class="fas fa-${this.getNotificationIcon(type)}"></i>
                <span>${message}</span>
            </div>
        `;
        
        // Add styles
        const style = document.createElement('style');
        style.textContent = `
            .notification {
                position: fixed;
                top: 20px;
                right: 20px;
                background: var(--surface-color);
                border: 1px solid var(--border-color);
                border-radius: 10px;
                padding: 1rem 1.5rem;
                box-shadow: var(--shadow-lg);
                z-index: 1000;
                animation: slideInRight 0.3s ease;
            }
            .notification-success {
                border-left: 4px solid var(--secondary-color);
            }
            .notification-error {
                border-left: 4px solid var(--warning-color);
            }
            .notification-info {
                border-left: 4px solid var(--primary-color);
            }
            .notification-content {
                display: flex;
                align-items: center;
                gap: 0.5rem;
            }
            @keyframes slideInRight {
                from {
                    transform: translateX(100%);
                    opacity: 0;
                }
                to {
                    transform: translateX(0);
                    opacity: 1;
                }
            }
        `;
        
        if (!document.querySelector('#notification-styles')) {
            style.id = 'notification-styles';
            document.head.appendChild(style);
        }
        
        document.body.appendChild(notification);
        
        // Auto remove after 5 seconds
        setTimeout(() => {
            if (notification.parentNode) {
                notification.style.animation = 'slideInRight 0.3s ease reverse';
                setTimeout(() => notification.remove(), 300);
            }
        }, 5000);
    }
    
    getNotificationIcon(type) {
        const icons = {
            success: 'check-circle',
            error: 'exclamation-circle',
            info: 'info-circle'
        };
        return icons[type] || 'info-circle';
    }
    
    loadSampleData() {
        // Pre-fill with sample domain for demonstration
        this.domainInput.placeholder = "example.com";
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
    }
    
    setupNavigation() {
        this.navLinks.forEach(link => {
            link.addEventListener('click', (e) => {
                if (!link.href.includes(window.location.hostname)) {
                    return;
                }
                
                e.preventDefault();
                this.setActiveLink(link);
                
                setTimeout(() => {
                    window.location.href = link.href;
                }, 800);
            });
        });
    }
    
    setActiveLink(activeLink) {
        this.navLinks.forEach(link => {
            link.classList.remove('active');
        });
        activeLink.classList.add('active');
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
        this.subdomainScanner = new SubdomainScanner();
        this.navManager = new NavigationManager();
        this.socialManager = new SocialMediaManager();
        this.backgroundAnimation = new BackgroundAnimation();
        
        this.init();
    }
    
    init() {
        this.setupPageLoad();
        this.setupIntersectionObserver();
    }
    
    setupPageLoad() {
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
        
        document.querySelectorAll('.search-card, .feature, .info-card').forEach(el => {
            observer.observe(el);
        });
    }
}

// Initialize the application
document.addEventListener('DOMContentLoaded', () => {
    window.app = new App();
    window.subdomainScanner = window.app.subdomainScanner;
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

window.utils = utils;
