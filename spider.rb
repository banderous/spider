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
    return urls.compact.select {|x| nil == x.host || x.host == domain}.map {|x| x.to_s}
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
        urls = filterInvalidURLs(extractUrlsFromPage(doc))
        urls = filterUrlsToDomain(@domain, urls)
        return Page.new(url, urls, extractStaticResourcesFromPage(doc))
    end
end

class Spider

    attr_accessor :pageMap
    
    def initialize(domain, pageFetcher)
        @domain = domain
        @fetcher = pageFetcher
        @pageMap = Hash.new
        go(domain)
    end
    
    def go(url)
        url = URI.join(@domain, url)
        if (@pageMap.has_key?(url))
            return
        end
        page = @fetcher.fetch(url)
        @pageMap[url] = page
        page.links.each {|x| go(x)}
    end
end

def renderPagesToHtml(domain, pages)
    builder = Nokogiri::HTML::Builder.new do |doc|
    doc.html {
        doc.body() {
            pages.each do |page|
                links = page.links.map {|x| "#" + x}
                resources = page.staticResources.map {|x| URI.join(domain, x)}
                doc.h1 {
                    path = URI(page.url).path
                    path = path == nil || path.length == 0 ? page.url : path
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
    spider = Spider.new(domain, HttpPageFetcher.new(domain))
    puts renderPagesToHtml(domain, spider.pageMap.values)
else
    puts "Usage: domain"
    puts "Eg: http://example.com > example.html"
end
