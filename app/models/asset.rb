class Asset < ActiveRecord::Base
  
  has_many :related_assets, :dependent => :destroy
  has_many :pages, :through => :related_assets
  
  has_attached_file(
    :upload,
    :styles => {
      :medium   => "300x300",
      :thumb    => "100x100",
      :headline => "460x250#"
    }
  )
  
  scope :images, :conditions => {
    :upload_content_type => [
      "image/gif",
      "image/jpeg",
      "image/png"
    ]
  }
  
  scope :documents, :conditions => {
    :upload_content_type => [
      "application/pdf",
      "text/plain",
      "text/rtf"
    ]
  }
  
  scope :audio, :conditions => {
    :upload_content_type => [
      "audio/mpeg",
      "audio/x-m4a",
      "audio/wav",
      "audio/x-wav"
    ]
  }
end
