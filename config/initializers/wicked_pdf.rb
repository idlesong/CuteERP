# WickedPDF Global Configuration
#
# Use this to set up shared configuration options for your entire application.
# Any of the configuration options shown here can also be applied to single
# models by passing arguments to the `render :pdf` call.
#
# To learn more, check out the README:
#
# https://github.com/mileszs/wicked_pdf/blob/master/README.md

WickedPdf.configure do |config|
  # Path to the wkhtmltopdf executable (provided by the wkhtmltopdf-binary gem).
  config.exe_path = Gem.bin_path("wkhtmltopdf-binary", "wkhtmltopdf")

  # Layout file to be used for all PDFs
  # (but can be overridden in `render :pdf` calls)
  # config.layout = "pdf.html"
end
