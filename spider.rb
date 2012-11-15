#!/usr/bin/env ruby

require 'uri'

def extractUrlsFromPage(html)
    doc = Nokogiri::HTML(html)
    return doc.xpath("//a").map {|x| x['href']}
end

def extractStaticResourcesFromPage(html)
    doc = Nokogiri::HTML(html)
    return doc.xpath("//*[@src]").map {|x| x['src']}
end

def filterUrlsToDomain(domain, urls)
    urls = urls.map {|x| URI(x)}
    return urls.select {|x| nil == x.host || x.host == domain}.map {|x| String(x)}
end

class Page
    attr_accessor :url
    attr_accessor :links
    
    def initialize(url, containsUrls, staticResources)
        @url = url
        @links = containsUrls
        @staticResources = staticResources
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
        if (@pageMap.has_key?(url))
            return
        end
        page = @fetcher.fetch(url)
        @pageMap[url] = page
        page.links.each {|x| go(x)}
    end
end

class UrlFetcher

    def fetch(url)
        
    end
    
end
