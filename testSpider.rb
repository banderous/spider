#!/usr/bin/env ruby

require_relative "spider"
require "nokogiri"
require "test/unit"
require "addressable/uri"

class FakePageFetcher
    
    def initialize(pages)
        @pages = pages
    end
    
    def fetch(url)
        return @pages.find {|x| x.url == url}
    end
end

class TestSpider < Test::Unit::TestCase
    
    def testLinksExtracted
        assert_equal(["/about"], extractUrlsFromPage("<a href=\"/about\"/>"))
    end
  
    def testLinksInsideDomainIncluded
        urls = ["/about", "support.example.com/help"]
        assert_equal(urls, filterUrlsToDomain("example.com", urls))
    end
    
    def testLinksOutsideOfDomainExcluded
        assert_equal([], filterUrlsToDomain("example.com", ["http://another.domain.com/goodbye"]))
    end
    
    def testStaticResourcesExtracted
       assert_equal(["/sneezingPanda.mov"],
                    extractStaticResourcesFromPage("<hasSrcAttribute src=\"/sneezingPanda.mov\"/>"))
    end
    
    def testSingleCircularPage
        domain = "example.com"
        # Our homepage has a single link to itself
        homePage = Page.new(domain, [domain], [])
        pages = FakePageFetcher.new([homePage])
        spider = Spider.new(domain, pages)
        assert_equal([homePage], spider.pageMap.values)
    end
    
    def testTwoCircularlyLinkedPages
        domain = "example.com"
        
        # About links to home
        aboutPage = Page.new("/about", [domain], [])
        
        # Home page links to about
        homePage = Page.new(domain, [aboutPage.url], [])
            
        pages = FakePageFetcher.new([homePage, aboutPage])
        spider = Spider.new(domain, pages)
        assert_equal([homePage, aboutPage], spider.pageMap.values)
    end
end
