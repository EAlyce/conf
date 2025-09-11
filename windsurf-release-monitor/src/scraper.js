const axios = require('axios');
const cheerio = require('cheerio');
const { logger, apiRequest, errorWithContext } = require('./logger');
const { config } = require('./config');

class WindsurfScraper {
  constructor() {
    this.axiosInstance = axios.create({
      timeout: config.monitoring.requestTimeout,
      headers: {
        'User-Agent': 'WindsurfReleaseMonitor/1.0 (+https://github.com/windsurf-release-monitor)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate',
        'DNT': '1',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1'
      }
    });
  }

  /**
   * Fetch page content with retry logic
   */
  async fetchPage(url, retries = config.monitoring.maxRetries) {
    const startTime = Date.now();
    
    for (let attempt = 1; attempt <= retries; attempt++) {
      try {
        const response = await this.axiosInstance.get(url);
        const duration = Date.now() - startTime;
        
        apiRequest(url, 'GET', response.status, duration);
        
        if (response.status === 200) {
          return response.data;
        }
        
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      } catch (error) {
        const duration = Date.now() - startTime;
        apiRequest(url, 'GET', error.response?.status || 'ERROR', duration);
        
        if (attempt === retries) {
          errorWithContext('Failed to fetch page after all retries', error, { url, attempts: retries });
          throw error;
        }
        
        const delay = Math.min(1000 * Math.pow(2, attempt - 1), 10000); // Exponential backoff, max 10s
        logger.warn(`Fetch attempt ${attempt} failed, retrying in ${delay}ms`, { url, error: error.message });
        
        await this.sleep(delay);
      }
    }
  }

  /**
   * Sleep utility
   */
  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Parse stable releases from /editor/releases page
   */
  async parseStableReleases() {
    try {
      logger.info('Fetching stable releases');
      const html = await this.fetchPage(config.windsurf.stableReleasesUrl);
      const $ = cheerio.load(html);
      
      const releases = [];
      
      // Look for version headers (h2 elements with version numbers)
      $('h2').each((index, element) => {
        const versionText = $(element).text().trim();
        const versionMatch = versionText.match(/^(\d+\.\d+\.\d+)$/);
        
        if (versionMatch) {
          const version = versionMatch[1];
          const downloads = {};
          
          // Find the next section after this h2 to get download links
          let nextElement = $(element).next();
          while (nextElement.length && !nextElement.is('h2')) {
            if (nextElement.is('h3')) {
              const platform = nextElement.text().trim();
              let linkElement = nextElement.next();
              
              while (linkElement.length && !linkElement.is('h2, h3')) {
                if (linkElement.is('a')) {
                  const linkText = linkElement.text().trim();
                  const linkHref = linkElement.attr('href');
                  
                  if (linkHref && linkText) {
                    if (!downloads[platform]) {
                      downloads[platform] = [];
                    }
                    downloads[platform].push({
                      name: linkText,
                      url: linkHref.startsWith('http') ? linkHref : `https://windsurf.com${linkHref}`
                    });
                  }
                }
                linkElement = linkElement.next();
              }
            }
            nextElement = nextElement.next();
          }
          
          // Look for changelog link
          const changelogLink = $(`a[href*="changelog"]:contains("${version}")`).first();
          const changelog = changelogLink.length ? 
            (changelogLink.attr('href').startsWith('http') ? 
              changelogLink.attr('href') : 
              `https://windsurf.com${changelogLink.attr('href')}`) : 
            `${config.windsurf.changelogBaseUrl}#${version}`;
          
          releases.push({
            version,
            type: 'stable',
            downloads,
            changelog,
            detectedAt: new Date().toISOString(),
            sourceUrl: config.windsurf.stableReleasesUrl
          });
        }
      });
      
      logger.info(`Found ${releases.length} stable releases`);
      return releases;
    } catch (error) {
      errorWithContext('Failed to parse stable releases', error);
      return [];
    }
  }

  /**
   * Parse Next releases from changelog page
   */
  async parseNextReleases() {
    try {
      logger.info('Fetching Next releases');
      const html = await this.fetchPage(config.windsurf.nextReleasesUrl);
      const $ = cheerio.load(html);
      
      const releases = [];
      
      // Look for version information in the changelog
      $('h1, h2, h3').each((index, element) => {
        const headerText = $(element).text().trim();
        
        // Look for version patterns or release dates
        const versionMatch = headerText.match(/(\d+\.\d+\.\d+)|Next\s+(\d{4}-\d{2}-\d{2})|Wave\s+(\d+)/i);
        
        if (versionMatch || headerText.toLowerCase().includes('patch fixes') || 
            headerText.toLowerCase().includes('improvements') || 
            headerText.toLowerCase().includes('new features')) {
          
          // Extract content following this header
          const content = [];
          let nextElement = $(element).next();
          
          while (nextElement.length && !nextElement.is('h1, h2, h3')) {
            if (nextElement.is('ul, ol')) {
              nextElement.find('li').each((i, li) => {
                content.push($(li).text().trim());
              });
            } else if (nextElement.is('p')) {
              const text = nextElement.text().trim();
              if (text) content.push(text);
            }
            nextElement = nextElement.next();
          }
          
          if (content.length > 0) {
            // Generate a version identifier for Next releases
            const timestamp = new Date().toISOString().split('T')[0];
            const versionId = versionMatch ? 
              (versionMatch[1] || `next-${versionMatch[2] || versionMatch[3] || timestamp}`) :
              `next-${timestamp}-${headerText.toLowerCase().replace(/[^a-z0-9]/g, '-').substring(0, 20)}`;
            
            releases.push({
              version: versionId,
              type: 'next',
              title: headerText,
              changes: content,
              changelog: config.windsurf.nextReleasesUrl,
              downloadUrl: config.windsurf.nextDownloadUrl,
              detectedAt: new Date().toISOString(),
              sourceUrl: config.windsurf.nextReleasesUrl
            });
          }
        }
      });
      
      // Remove duplicates and keep only the most recent ones
      const uniqueReleases = releases
        .filter((release, index, self) => 
          index === self.findIndex(r => r.version === release.version))
        .slice(0, 10); // Keep only last 10 Next releases
      
      logger.info(`Found ${uniqueReleases.length} Next releases`);
      return uniqueReleases;
    } catch (error) {
      errorWithContext('Failed to parse Next releases', error);
      return [];
    }
  }

  /**
   * Get download links for Next releases
   */
  async getNextDownloadLinks() {
    try {
      const html = await this.fetchPage(config.windsurf.nextDownloadUrl);
      const $ = cheerio.load(html);
      
      const downloads = {
        macOS: [],
        Windows: [],
        Linux: []
      };
      
      // Look for download buttons or links
      $('a[href*="download"], button[onclick*="download"]').each((index, element) => {
        const text = $(element).text().trim().toLowerCase();
        const href = $(element).attr('href') || $(element).attr('onclick');
        
        if (href) {
          let platform = 'Other';
          if (text.includes('mac') || text.includes('darwin')) platform = 'macOS';
          else if (text.includes('windows') || text.includes('win')) platform = 'Windows';
          else if (text.includes('linux') || text.includes('ubuntu') || text.includes('debian')) platform = 'Linux';
          
          downloads[platform].push({
            name: $(element).text().trim(),
            url: href.startsWith('http') ? href : `https://windsurf.com${href}`
          });
        }
      });
      
      return downloads;
    } catch (error) {
      errorWithContext('Failed to get Next download links', error);
      return {};
    }
  }

  /**
   * Get all releases (stable + next)
   */
  async getAllReleases() {
    try {
      logger.info('Starting release scraping');
      
      const [stableReleases, nextReleases] = await Promise.allSettled([
        this.parseStableReleases(),
        this.parseNextReleases()
      ]);
      
      const results = {
        stable: stableReleases.status === 'fulfilled' ? stableReleases.value : [],
        next: nextReleases.status === 'fulfilled' ? nextReleases.value : [],
        errors: []
      };
      
      if (stableReleases.status === 'rejected') {
        results.errors.push({ type: 'stable', error: stableReleases.reason.message });
      }
      
      if (nextReleases.status === 'rejected') {
        results.errors.push({ type: 'next', error: nextReleases.reason.message });
      }
      
      // Add download links to Next releases
      if (results.next.length > 0) {
        try {
          const nextDownloads = await this.getNextDownloadLinks();
          results.next.forEach(release => {
            release.downloads = nextDownloads;
          });
        } catch (error) {
          logger.warn('Failed to get Next download links', { error: error.message });
        }
      }
      
      logger.info('Release scraping completed', {
        stable: results.stable.length,
        next: results.next.length,
        errors: results.errors.length
      });
      
      return results;
    } catch (error) {
      errorWithContext('Failed to get all releases', error);
      throw error;
    }
  }
}

module.exports = new WindsurfScraper();
