require 'redmine_s3/attachment_patch'
require 'redmine_s3/attachments_controller_patch'
require 'redmine_s3/application_helper_patch'
require 'redmine_s3/thumbnail_patch'
require 'redmine_s3/connection'

Attachment.__send__(:include, RedmineS3::AttachmentPatch)
ApplicationHelper.__send__(:include, RedmineS3::ApplicationHelperPatch)
AttachmentsController.__send__(:include, RedmineS3::AttachmentsControllerPatch)
RedmineS3::Connection.create_bucket
