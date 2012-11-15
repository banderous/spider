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

def filterUrlsToDomain(domain, urls)
    urls = urls.map {|x| URI(x)}
    filtered = urls.select {|x| nil == x.host || x.host == domain}.map {|x| x.to_s}
    invalidUrlRegexes = [/^\/$/, /^#/, /^javascript/, /^mailto:/]
    return filtered.select {|x| invalidUrlRegexes.map {|r| r.match(x)}.compact.empty?}
end

class Page
    attr_accessor :url
    attr_accessor :links
    attr_accessor :staticResources
    
    def initialize(url, links, staticResources)
        @url = url
        @links = links
        @staticResources = staticResources
    end
end

def renderPageToHtml(page)
    builder = Nokogiri::HTML::Builder.new do |doc|
    doc.html {
        doc.body() {
            doc.h1(page.url)
            [["Links to:", page.links],
             ["References resources:", page.staticResources]].each do |title, urls|
                doc.h1(title)
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
        end
        
        doc = Nokogiri::HTML(stream)
        urls = filterUrlsToDomain(@domain, extractUrlsFromPage(doc))
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
