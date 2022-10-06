module RedmicaS3
  module AttachmentsControllerPatch
    extend ActiveSupport::Concern

    included do
      prepend PrependMethods
    end

    class_methods do
    end

    module PrependMethods

      def show
        respond_to do |format|
          format.html {
            if @attachment.container.respond_to?(:attachments)
              @attachments = @attachment.container.attachments.to_a
              if index = @attachments.index(@attachment)
                @paginator = Redmine::Pagination::Paginator.new(
                  @attachments.size, 1, index+1
                )
              end
            end
            if @attachment.is_diff?
              @diff = @attachment.raw_data
              @diff_type = params[:type] || User.current.pref[:diff_type] || 'inline'
              @diff_type = 'inline' unless %w(inline sbs).include?(@diff_type)
              # Save diff type as user preference
              if User.current.logged? && @diff_type != User.current.pref[:diff_type]
                User.current.pref[:diff_type] = @diff_type
                User.current.preference.save
              end
              render action: 'diff'
            elsif @attachment.is_text? && @attachment.filesize <= Setting.file_max_size_displayed.to_i.kilobyte
              @content = @attachment.raw_data
              render action: 'file'
            elsif @attachment.is_image?
              render action: 'image'
            else
              render action: 'other'
            end
          }
          format.api
        end
      end

      def download
        if @attachment.container.is_a?(Version) || @attachment.container.is_a?(Project)
          @attachment.increment_download
        end

        if stale?(etag: @attachment.digest, template: false)
          send_data @attachment.raw_data,
            filename: filename_for_content_disposition(@attachment.filename),
            type: detect_content_type(@attachment),
            disposition: disposition(@attachment)
        end
      end

      def thumbnail
        begin
          raise unless @attachment.thumbnailable?
          cache_key = "#{ENV['RAILS_DB']}/attachments/thumbnail/#{params[:id]}/#{params[:filename]}"
          p 'cache key ------------------------------------------------'
          p cache_key
          digest, raw_data = Rails.cache.fetch(cache_key, expired_in: 30.minutes) do
            @attachment.thumbnail(:size => params[:size])
          end
          # digest, raw_data = @attachment.thumbnail(:size => params[:size])
          raise unless raw_data
          if stale?(etag: digest, template: false)

          # if stale?(etag: @attachment.thumbnail_path(params[:size].presence || Setting.thumbnails_size), template: false)
          #   digest, raw_data = @attachment.thumbnail(:size => params[:size])
          #   raise unless raw_data

            send_data raw_data,
              filename: filename_for_content_disposition(@attachment.filename),
              type: detect_content_type(@attachment, true),
              disposition: 'inline'
          end
        rescue
          # No thumbnail for the attachment or thumbnail could not be created
          head 404
        end
      end

    end

  end
end
