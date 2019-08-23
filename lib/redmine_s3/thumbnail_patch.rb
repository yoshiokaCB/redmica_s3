module RedmineS3
  module ThumbnailPatch
    extend ActiveSupport::Concern

    included do
      prepend PrependMethods
    end

    class_methods do
    end

    module PrependMethods
      def self.prepended(base)
        class << base
          self.prepend(ClassMethods)
        end
      end

      module ClassMethods
        # Generates a thumbnail for the source image to target
        def generate(source, target, size, is_pdf = false)
          return nil unless convert_available?
          return nil if is_pdf && !gs_available?

          target_folder = RedmineS3::Connection.thumb_folder
          object = RedmineS3::Connection.object(target, target_folder)
          unless object.exists?
            return nil unless Object.const_defined?(:MiniMagick)

            require 'open-uri'
            url = RedmineS3::Connection.object_url(source)
            raw_data = nil
            open(url, 'rb') do |f| raw_data = f.read end
            mime_type = MimeMagic.by_magic(raw_data).try(:type)
            return nil if mime_type.nil?
            return nil if !ALLOWED_TYPES.include? mime_type
            return nil if is_pdf && mime_type != "application/pdf"

            size_option = "#{size}x#{size}>"
            begin
              tempfile = MiniMagick::Utilities.tempfile(File.extname(source)) do |f| f.write(raw_data) end
              convert_output =
                if is_pdf
                  MiniMagick::Tool::Convert.new do |cmd|
                    cmd << "#{tempfile.to_path}[0]"
                    cmd.thumbnail size_option
                    cmd << 'png:-'
                  end
                else
                  MiniMagick::Tool::Convert.new do |cmd|
                    cmd << tempfile.to_path
                    cmd.auto_orient
                    cmd.thumbnail size_option
                    cmd << '-'
                  end
                end
              img = MiniMagick::Image.read(convert_output)

              RedmineS3::Connection.put(target, File.basename(target), img.to_blob, img.mime_type, {target_folder: target_folder})
            rescue => e
              Rails.logger.error("Creating thumbnail failed (#{e.message}):")
              return nil
            ensure
              tempfile.unlink if tempfile
            end
          end

          RedmineS3::Connection.object_url(target, target_folder)
        end
      end
    end
  end
end
