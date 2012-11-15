#!/usr/bin/env ruby

require_relative "spider"
require "nokogiri"
require "test/unit"

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
        invalidUrls = ["/", "javascript:blah" "#foo-bar", "mailto:a@b.com"]
        assert_equal([], filterUrlsToDomain("example.com", invalidUrls))
    end
  
    def testStaticResourcesExtracted
       assert_equal(["/sneezingPanda.mov"],
                    extractStaticResourcesFromPage(Nokogiri::HTML("<hasSrcAttribute src=\"/sneezingPanda.mov\"/>")))
    end
    
    def testLinksInsideDomainIncluded
        urls = ["/about", "support.example.com/help"]
        assert_equal(urls, filterUrlsToDomain("example.com", urls))
    end
    
    def testLinksOutsideOfDomainExcluded
        assert_equal([], filterUrlsToDomain("example.com", ["http://another.domain.com/goodbye"]))
    end
    
    def testSingleCircularPage
        domain = "http://example.com"
        # Our homepage has a single link to itself
        homePage = Page.new(domain, [domain], [])
        pages = FakePageFetcher.new(domain, [homePage])
        pages.fetch(domain)
        spider = Spider.new(domain, pages)
        assert_equal([homePage], spider.pageMap.values)
    end
    
    def testTwoCircularlyLinkedPages
        domain = "http://example.com"
        
        # About links to home
        aboutPage = Page.new("/about", [domain], [])
        
        # Home page links to about
        homePage = Page.new(domain, [aboutPage.url], [])
            
        pages = FakePageFetcher.new(domain, [homePage, aboutPage])
        spider = Spider.new(domain, pages)
        assert_equal([homePage, aboutPage], spider.pageMap.values)
    end

    def testPageToHTMLReportGeneration
        page = Page.new("example.com", ["/about", "/contact"], ["/sleepingKitten.jpg"])
        renderPageToHtml(page)
    end
    
  #  def testHomepage
  #      fetcher = HttpPageFetcher.new("https://gocardless.com")
  #      page = fetcher.fetch("https://gocardless.com")
  #      puts page.links;
  #      #File.open("test.html", 'w') {|f| f.write(renderPageToHtml(page)) }
  #  end
    
   # def testCrawlOutline
   #     domain = "http://outlinegames.com"
   #     spider = Spider.new(domain, HttpPageFetcher.new(domain))
        
   #     spider.pageMap.values.each {|x| File.open(domain + "/" + x.url + ".html", 'w') {|f| f.write(renderPageToHtml(x)) } }
   # end
end
