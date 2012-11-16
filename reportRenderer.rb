#!/usr/bin/env ruby

require 'spider'

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
