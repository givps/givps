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
        this.resultsTable = document.getElementById('resultsTable');
        this.resultsCount = document.getElementById('resultsCount');
        this.loadingResults = document.getElementById('loadingResults');
        this.noResults = document.getElementById('noResults');
        this.wildcardCheckbox = document.getElementById('wildcardCheckbox');
        this.uniqueCheckbox = document.getElementById('uniqueCheckbox');
        
        this.currentResults = [];
        this.filteredResults = [];
        this.currentPage = 1;
        this.itemsPerPage = 10;
        this.currentSort = { column: 'subdomain', direction: 'asc' };
        
        this.init();
    }
    
    init() {
        this.setupEventListeners();
        this.setupFilters();
    }
    
    setupEventListeners() {
        this.searchBtn.addEventListener('click', () => {
            this.scanDomain();
        });
        
        this.domainInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.scanDomain();
            }
        });
        
        // Enter domain from URL parameter
        const urlParams = new URLSearchParams(window.location.search);
        const domainParam = urlParams.get('domain');
        if (domainParam) {
            this.domainInput.value = domainParam;
            setTimeout(() => this.scanDomain(), 500);
        }
    }
    
    setupFilters() {
        const statusFilter = document.getElementById('statusFilter');
        const typeFilter = document.getElementById('typeFilter');
        const searchFilter = document.getElementById('searchFilter');
        const exportBtn = document.getElementById('exportBtn');
        
        // Debounced filter function
        const applyFilters = utils.debounce(() => {
            this.applyFilters();
        }, 300);
        
        statusFilter.addEventListener('change', applyFilters);
        typeFilter.addEventListener('change', applyFilters);
        searchFilter.addEventListener('input', applyFilters);
        
        exportBtn.addEventListener('click', () => {
            this.exportToCSV();
        });
        
        // Table sorting
        document.querySelectorAll('.results-table th[data-sort]').forEach(th => {
            th.addEventListener('click', () => {
                const column = th.getAttribute('data-sort');
                this.sortResults(column);
            });
        });
        
        // Pagination
        document.getElementById('prevPage').addEventListener('click', () => {
            this.previousPage();
        });
        
        document.getElementById('nextPage').addEventListener('click', () => {
            this.nextPage();
        });
    }
    
    async scanDomain() {
        const domain = this.domainInput.value.trim();
        
        if (!domain) {
            this.showError('Please enter a domain name');
            return;
        }
        
        // Validate domain format
        if (!this.isValidDomain(domain)) {
            this.showError('Please enter a valid domain name');
            return;
        }
        
        this.showLoading();
        this.searchBtn.disabled = true;
        
        try {
            const subdomains = await this.fetchSubdomains(domain);
            this.currentResults = subdomains;
            this.applyFilters();
            this.showResults();
            
        } catch (error) {
            console.error('Scan error:', error);
            this.showError('Failed to scan domain. Please try again.');
        } finally {
            this.hideLoading();
            this.searchBtn.disabled = false;
        }
    }
    
    async fetchSubdomains(domain) {
        const apiUrl = `https://crt.sh/?q=%25.${domain}&output=json`;
        
        const response = await fetch(apiUrl);
        if (!response.ok) {
            throw new Error('API request failed');
        }
        
        const data = await response.json();
        return this.processSubdomainData(data, domain);
    }
    
    processSubdomainData(data, domain) {
        const subdomains = new Map();
        
        data.forEach(cert => {
            const commonName = cert.common_name;
            
            if (commonName && this.isSubdomain(commonName, domain)) {
                // Skip wildcard certificates if not wanted
                if (!this.wildcardCheckbox.checked && commonName.includes('*')) {
                    return;
                }
                
                const subdomain = commonName.replace('*.', '');
                
                if (this.uniqueCheckbox.checked && subdomains.has(subdomain)) {
                    return;
                }
                
                subdomains.set(subdomain, {
                    subdomain: subdomain,
                    domain: domain,
                    issuer: cert.issuer_name || 'Unknown',
                    not_before: cert.not_before ? new Date(cert.not_before) : null,
                    not_after: cert.not_after ? new Date(cert.not_after) : null,
                    status: this.checkCertificateStatus(cert.not_after),
                    type: this.getSubdomainType(subdomain)
                });
            }
        });
        
        return Array.from(subdomains.values());
    }
    
    isSubdomain(name, domain) {
        return name.endsWith('.' + domain) || name === domain;
    }
    
    isValidDomain(domain) {
        const domainRegex = /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;
        return domainRegex.test(domain);
    }
    
    checkCertificateStatus(notAfter) {
        if (!notAfter) return 'unknown';
        
        const expiryDate = new Date(notAfter);
        const now = new Date();
        
        if (expiryDate < now) {
            return 'inactive';
        }
        
        // Check if certificate expires within 30 days
        const thirtyDaysFromNow = new Date();
        thirtyDaysFromNow.setDate(thirtyDaysFromNow.getDate() + 30);
        
        if (expiryDate < thirtyDaysFromNow) {
            return 'expiring';
        }
        
        return 'active';
    }
    
    getSubdomainType(subdomain) {
        const types = {
            'www': 'www',
            'api': 'api',
            'mail': 'mail',
            'smtp': 'mail',
            'pop': 'mail',
            'imap': 'mail',
            'ftp': 'ftp',
            'cpanel': 'cpanel',
            'admin': 'cpanel',
            'blog': 'other',
            'shop': 'other',
            'store': 'other',
            'app': 'other',
            'dev': 'other',
            'test': 'other',
            'staging': 'other'
        };
        
        const parts = subdomain.split('.');
        const mainPart = parts.length > 0 ? parts[0] : '';
        
        return types[mainPart] || 'other';
    }
    
    applyFilters() {
        const statusFilter = document.getElementById('statusFilter').value;
        const typeFilter = document.getElementById('typeFilter').value;
        const searchFilter = document.getElementById('searchFilter').value.toLowerCase();
        
        this.filteredResults = this.currentResults.filter(item => {
            // Status filter
            if (statusFilter !== 'all' && item.status !== statusFilter && 
                !(statusFilter === 'active' && (item.status === 'active' || item.status === 'expiring'))) {
                return false;
            }
            
            // Type filter
            if (typeFilter !== 'all' && item.type !== typeFilter) {
                return false;
            }
            
            // Search filter
            if (searchFilter && !item.subdomain.toLowerCase().includes(searchFilter)) {
                return false;
            }
            
            return true;
        });
        
        this.resultsCount.textContent = this.filteredResults.length;
        this.currentPage = 1;
        this.renderTable();
        this.updatePagination();
    }
    
    sortResults(column) {
        if (this.currentSort.column === column) {
            this.currentSort.direction = this.currentSort.direction === 'asc' ? 'desc' : 'asc';
        } else {
            this.currentSort.column = column;
            this.currentSort.direction = 'asc';
        }
        
        this.filteredResults.sort((a, b) => {
            let aValue = a[column];
            let bValue = b[column];
            
            if (column === 'not_before' || column === 'not_after') {
                aValue = aValue ? new Date(aValue) : new Date(0);
                bValue = bValue ? new Date(bValue) : new Date(0);
            }
            
            if (aValue < bValue) return this.currentSort.direction === 'asc' ? -1 : 1;
            if (aValue > bValue) return this.currentSort.direction === 'asc' ? 1 : -1;
            return 0;
        });
        
        this.renderTable();
        this.updateSortIndicators();
    }
    
    updateSortIndicators() {
        document.querySelectorAll('.results-table th i').forEach(icon => {
            icon.className = 'fas fa-sort';
        });
        
        const currentTh = document.querySelector(`.results-table th[data-sort="${this.currentSort.column}"] i`);
        if (currentTh) {
            currentTh.className = this.currentSort.direction === 'asc' ? 'fas fa-sort-up' : 'fas fa-sort-down';
        }
    }
    
    renderTable() {
        const startIndex = (this.currentPage - 1) * this.itemsPerPage;
        const endIndex = startIndex + this.itemsPerPage;
        const pageData = this.filteredResults.slice(startIndex, endIndex);
        
        if (pageData.length === 0) {
            this.resultsTable.innerHTML = '';
            return;
        }
        
        this.resultsTable.innerHTML = pageData.map(item => `
            <tr>
                <td>
                    <strong>${this.escapeHtml(item.subdomain)}</strong>
                </td>
                <td>${this.escapeHtml(item.domain)}</td>
                <td>${this.escapeHtml(this.truncateText(item.issuer, 30))}</td>
                <td>${item.not_before ? item.not_before.toLocaleDateString() : 'N/A'}</td>
                <td>${item.not_after ? item.not_after.toLocaleDateString() : 'N/A'}</td>
                <td>
                    <span class="status-badge status-${item.status}">
                        ${this.getStatusText(item.status)}
                    </span>
                </td>
            </tr>
        `).join('');
    }
    
    getStatusText(status) {
        const statusMap = {
            'active': 'Active',
            'expiring': 'Expiring Soon',
            'inactive': 'Expired',
            'unknown': 'Unknown'
        };
        return statusMap[status] || 'Unknown';
    }
    
    updatePagination() {
        const totalPages = Math.ceil(this.filteredResults.length / this.itemsPerPage);
        const pagination = document.getElementById('pagination');
        const currentPageElem = document.getElementById('currentPage');
        const totalPagesElem = document.getElementById('totalPages');
        const prevBtn = document.getElementById('prevPage');
        const nextBtn = document.getElementById('nextPage');
        
        currentPageElem.textContent = this.currentPage;
        totalPagesElem.textContent = totalPages;
        
        prevBtn.disabled = this.currentPage === 1;
        nextBtn.disabled = this.currentPage === totalPages;
        
        if (totalPages > 1) {
            pagination.style.display = 'flex';
        } else {
            pagination.style.display = 'none';
        }
    }
    
    previousPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.renderTable();
            this.updatePagination();
        }
    }
    
    nextPage() {
        const totalPages = Math.ceil(this.filteredResults.length / this.itemsPerPage);
        if (this.currentPage < totalPages) {
            this.currentPage++;
            this.renderTable();
            this.updatePagination();
        }
    }
    
    exportToCSV() {
        if (this.filteredResults.length === 0) {
            this.showError('No data to export');
            return;
        }
        
        const headers = ['Subdomain', 'Domain', 'Issuer', 'Valid From', 'Valid Until', 'Status'];
        const csvData = [
            headers,
            ...this.filteredResults.map(item => [
                item.subdomain,
                item.domain,
                item.issuer,
                item.not_before ? item.not_before.toISOString() : 'N/A',
                item.not_after ? item.not_after.toISOString() : 'N/A',
                this.getStatusText(item.status)
            ])
        ];
        
        const csvContent = csvData.map(row => 
            row.map(field => `"${field.replace(/"/g, '""')}"`).join(',')
        ).join('\n');
        
        const blob = new Blob([csvContent], { type: 'text/csv' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `subdomains-${this.domainInput.value}-${new Date().toISOString().split('T')[0]}.csv`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }
    
    showLoading() {
        this.loadingResults.style.display = 'block';
        this.noResults.style.display = 'none';
        this.resultsTable.innerHTML = '';
    }
    
    hideLoading() {
        this.loadingResults.style.display = 'none';
    }
    
    showResults() {
        this.resultsSection.style.display = 'block';
        
        if (this.filteredResults.length === 0) {
            this.noResults.style.display = 'block';
            this.resultsTable.innerHTML = '';
        } else {
            this.noResults.style.display = 'none';
        }
    }
    
    showError(message) {
        alert(message); // In a real app, you might want a better error display
    }
    
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
    
    truncateText(text, maxLength) {
        if (text.length <= maxLength) return text;
        return text.substring(0, maxLength) + '...';
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
                this.showLoadingState();
                
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
    
    showLoadingState() {
        const loader = document.createElement('div');
        loader.className = 'page-loader';
        loader.innerHTML = `
            <div class="loader-spinner"></div>
            <p>Navigating...</p>
        `;
        document.body.appendChild(loader);
        
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
        this.scanner = new SubdomainScanner();
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

// Initialize the application
document.addEventListener('DOMContentLoaded', () => {
    new App();
});

window.utils = utils;
