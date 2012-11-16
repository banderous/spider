#!/usr/bin/env ruby

require "addressable/uri"
require 'httpclient'
require "nokogiri"
require 'open-uri'
require 'uri'

INVALID_URL_REGEXES = [/^\/$/, /^#/, /^javascript/, /^mailto:/, /^tel:/]

def extractUrlsFromPage(nokogiriDoc)
    return nokogiriDoc.xpath("//a").map {|x| x['href']}.uniq
end

def extractStaticResourcesFromPage(nokogiriDoc)
    return nokogiriDoc.xpath("//*[@src]").map {|x| x['src']}.uniq
end

def filterInvalidURLs(urls)
    return urls.select {|x| INVALID_URL_REGEXES.map {|r| r.match(x)}.compact.empty?}.compact
end

def filterUrlsToDomain(domain, urls)
    urls = urls.map {|x| URI(x)}
    domain = URI(domain)
    urls = urls.compact.select do |x|
        nil == x.host || (x.host =~ /#{domain.host}$/) 
    end
    return urls.map {|x| x.to_s}
end

def sanitisePageForDomain(domain, page)
    return Page.new(page.url,
                    filterUrlsToDomain(domain, filterInvalidURLs(page.links)),
                    page.staticResources)
end

class Page
    attr_accessor :url
    attr_accessor :links
    attr_accessor :staticResources
    
    def initialize(url, links, staticResources)
        @url = url.to_s
        @links = links
        @staticResources = staticResources
    end
    
    def ==(other)
        [@url, @links, @staticResources] == [other.url, other.links, other.staticResources]
    end
end

class HttpPageFetcher
    
    def initialize(domain)
        @domain = domain
        @http = HTTPClient.new
    end
    
    def fetch(url)
        begin
            response = @http.get(url, :follow_redirect => true)
        rescue HTTPClient::BadResponseError # If https attempts to redirect to http.
            return Page.new(url,[],[])
        end
        doc = Nokogiri::HTML(response.body)
        return Page.new(url, extractUrlsFromPage(doc), extractStaticResourcesFromPage(doc))
    end
end

def do_spider(domain, pageFetcher, url = domain, pageMap = Hash.new)
    url = URI.join(domain, url)
    if (pageMap.has_key?(url))
        return
    end
    
    page = sanitisePageForDomain(domain, pageFetcher.fetch(url))
    pageMap[url] = page
    page.links.each {|x| do_spider(domain, pageFetcher, x, pageMap)}
    return pageMap.values
end

# Attempts to extract the path from a specified URL.
# If no path exists, url is returned.
def extractPathFromURL(url)
    path = URI(url).path
    return path == nil || path.length == 0 ? url : path    
end


# Generates an HTML report for a set of pages summaries,
# detailing each page's links and static resources.
def renderPagesToHtml(domain, pages)
    builder = Nokogiri::HTML::Builder.new do |doc|
    doc.html {
        doc.body() {
            pages.each do |page|
                links = page.links.map {|x| "#" + extractPathFromURL(x)}.sort.uniq
                resources = page.staticResources.map {|x| URI.join(domain, x)}
                doc.h1 {
                    path = extractPathFromURL(page.url)
                    doc.a(:name => path) {
                        doc.text path
                    }
                }
                [["Links to:", links],
                 ["References resources:", resources]].each do |title, urls|
                    doc.h2(title)
                    doc.ul {
                        urls.each do |l|
                            doc.li {
                                doc.a(:href => l) {
                                    doc.text l
                                }
                            }
                        end
                    }
                end
            end
        }
    }
    end
    return builder.to_html
end

if (ARGV.length == 1)
    domain = ARGV[0]
    puts renderPagesToHtml(domain, do_spider(domain, HttpPageFetcher.new(domain)))
else
    puts "Usage: domain"
    puts "Eg: http://example.com > example.html"
end
