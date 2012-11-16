#!/usr/bin/env ruby

require_relative "spider"
require "test/unit"

# Allows us to test our spider in isolation,
# without making HTTP requests.
class FakePageFetcher
    
    def initialize(domain, pages)
        @domain = domain
        @pages = pages
    end
    
    def fetch(url)
        return @pages.find {|x| URI.join(@domain, x.url) == url }
    end
end

class TestSpider < Test::Unit::TestCase

    def testLinksExtracted
        assert_equal(["/about#"], extractUrlsFromPage(Nokogiri::HTML("<a href=\"/about#\"/>")))
    end
    
    def testInvalidUrlsDiscarded
        invalidUrls = ["/", "javascript:blah", "#foo-bar", "mailto:a@b.com", "tel:999", nil]
        assert_equal([], filterInvalidURLs(invalidUrls))
    end
  
    def testStaticResourcesExtracted
       assert_equal(["/sneezingPanda.mov"],
                    extractStaticResourcesFromPage(Nokogiri::HTML("<hasSrcAttribute src=\"/sneezingPanda.mov\"/>")))
    end
    
    def testLinksInsideDomainIncluded
        urls = ["/about", "http://support.example.com/help", "support.example.com/help"]
        assert_equal(urls, filterUrlsToDomain("http://example.com", urls))
    end
    
    def testLinksOutsideOfDomainExcluded
        assert_equal([], filterUrlsToDomain("http://example.com", ["http://another.domain.com/goodbye"]))
    end
    
    def testSingleCircularPage
        domain = "http://example.com"
        # Our homepage has a single link to itself
        homePage = Page.new(domain, [domain], [])
        fetcher = FakePageFetcher.new(domain, [homePage])
        assert_equal([homePage], do_spider(domain, fetcher))
    end
    
    def testTwoCircularlyLinkedPages
        domain = "http://example.com"
        
        # About links to home
        aboutPage = Page.new("/about", [domain], [])
        
        # Home page links to about
        homePage = Page.new(domain, [aboutPage.url], [])
            
        fetcher = FakePageFetcher.new(domain, [homePage, aboutPage])
        assert_equal([homePage, aboutPage], do_spider(domain, fetcher))
    end
end
