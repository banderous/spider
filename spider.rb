#!/usr/bin/env ruby

require 'uri'
require 'open-uri'
require "addressable/uri"

def extractUrlsFromPage(nokogiriDoc)
    return nokogiriDoc.xpath("//a").map {|x| x['href']}.uniq
end

def extractStaticResourcesFromPage(nokogiriDoc)
    return nokogiriDoc.xpath("//*[@src]").map {|x| x['src']}.uniq
end

def filterInvalidURLs(urls)
    invalidUrlRegexes = [/^\/$/, /^#/, /^javascript/, /^mailto:/, /^tel:/]
    return urls.select {|x| invalidUrlRegexes.map {|r| r.match(x)}.compact.empty?}.compact
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

def renderPagesToHtml(pages)
    builder = Nokogiri::HTML::Builder.new do |doc|
    doc.html {
        doc.body() {
            pages.each do |page|
                doc.h1 {
                    path = URI(page.url).path
                    doc.a(:name => path) {
                        doc.text path
                    }
                }
                [["Links to:", page.links],
                 ["References resources:", page.staticResources]].each do |title, urls|
                    doc.h2(title)
                    doc.ul {
                        urls.each do |l|
                            doc.li {
                                doc.a(:href => "#" + l) {
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

class HttpPageFetcher
    
    def initialize(domain)
        @domain = domain
    end
    
    def fetch(url)
        begin
            stream = open(url)
        rescue TypeError => e
            puts "Unable to open:"
        rescue RuntimeError => r
            puts "Another"
        end
        
        doc = Nokogiri::HTML(stream)
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
