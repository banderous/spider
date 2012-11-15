#!/usr/bin/env ruby

require 'uri'
require 'open-uri'

def extractUrlsFromPage(nokogiriDoc)
    return nokogiriDoc.xpath("//a").map {|x| x['href']}.uniq
end

def extractStaticResourcesFromPage(nokogiriDoc)
    return nokogiriDoc.xpath("//*[@src]").map {|x| x['src']}.uniq
end

def filterUrlsToDomain(domain, urls)
    urls = urls.map {|x| URI(x)}
    return urls.select {|x| nil == x.host || x.host == domain}.map {|x| String(x)}
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

class HttpPageFetcher
    
    def initialize(domain)
        @domain = domain
    end
    
    def fetch(url)
        doc = Nokogiri::HTML(open(url))
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
