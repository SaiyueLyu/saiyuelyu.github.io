# require 'feedjira'
# require 'httparty'
# require 'jekyll'

# module ExternalPosts
#   class ExternalPostsGenerator < Jekyll::Generator
#     safe true
#     priority :high

#     def generate(site)
#       if site.config['external_sources'] != nil
#         site.config['external_sources'].each do |src|
#           p "Fetching external posts from #{src['name']}:"
#           xml = HTTParty.get(src['rss_url']).body
#           feed = Feedjira.parse(xml)
#           feed.entries.each do |e|
#             p "...fetching #{e.url}"
#             slug = e.title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
#             path = site.in_source_dir("_posts/#{slug}.md")
#             doc = Jekyll::Document.new(
#               path, { :site => site, :collection => site.collections['posts'] }
#             )
#             doc.data['external_source'] = src['name'];
#             doc.data['feed_content'] = e.content;
#             doc.data['title'] = "#{e.title}";
#             doc.data['description'] = e.summary;
#             doc.data['date'] = e.published;
#             doc.data['redirect'] = e.url;
#             site.collections['posts'].docs << doc
#           end
#         end
#       end
#     end
#   end

# end

require 'feedjira'
require 'httparty'
require 'jekyll'

module ExternalPosts
  class ExternalPostsGenerator < Jekyll::Generator
    safe true
    priority :high

    def generate(site)
      sources = site.config['external_sources']
      return if sources.nil? || sources.empty?

      # Optional: skip external fetching during local development
      if ENV['JEKYLL_ENV'] == 'development'
        Jekyll.logger.info "external-posts:", "Skipping external posts in development"
        return
      end

      sources.each do |src|
        name = src['name'] || 'unknown source'
        rss_url = src['rss_url']

        if rss_url.nil? || rss_url.empty?
          Jekyll.logger.warn "external-posts:", "Missing rss_url for #{name}"
          next
        end

        Jekyll.logger.info "external-posts:", "Fetching external posts from #{name}"

        begin
          response = HTTParty.get(rss_url, timeout: 10)

          unless response.success?
            Jekyll.logger.warn "external-posts:", "Failed to fetch #{rss_url} (HTTP #{response.code})"
            next
          end

          feed = Feedjira.parse(response.body)
          entries = feed&.entries || []

          entries.each do |e|
            next if e.url.nil? || e.title.nil?

            Jekyll.logger.info "external-posts:", "...fetching #{e.url}"

            slug = e.title.downcase.strip.gsub(/\s+/, '-').gsub(/[^\w-]/, '')
            path = site.in_source_dir("_posts/#{slug}.md")

            doc = Jekyll::Document.new(
              path,
              site: site,
              collection: site.collections['posts']
            )

            doc.data['external_source'] = name
            doc.data['feed_content'] = e.respond_to?(:content) ? e.content : nil
            doc.data['title'] = e.title.to_s
            doc.data['description'] = e.respond_to?(:summary) ? e.summary : nil
            doc.data['date'] = e.respond_to?(:published) && e.published ? e.published : Time.now
            doc.data['redirect'] = e.url

            site.collections['posts'].docs << doc
          end

        rescue StandardError => e
          Jekyll.logger.warn "external-posts:", "Skipping #{name} because fetch failed: #{e.class}: #{e.message}"
          next
        end
      end
    end
  end
end
