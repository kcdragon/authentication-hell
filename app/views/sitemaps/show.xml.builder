xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  [ root_url, acknowledgements_url, new_session_url, new_registration_url ].each do |url|
    xml.url { xml.loc url }
  end
end
