require 'rubygems'
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'prawn'
require 'prawn/chunk'

pdf = Prawn::Document.new()
pdf.text "this is top text"

pdf.y -= 100
pdf.text "above span"
pdf.span(200) do
  pdf.chunk_flow do
    pdf.chunk "line one"
    pdf.chunk_new_line
    pdf.chunk "line two"
    pdf.chunk_new_line
    pdf.chunk "line three"
    pdf.chunk_new_line
    pdf.chunk "line four"
  end
  #pdf.stroke_bounds
end
pdf.text "below span"

pdf.y -= 50
pdf.text "above bb with height"
pdf.bounding_box([0, pdf.cursor], :width => 200, :height => 150) do
  pdf.chunk_flow do
    pdf.chunk "line one", :size => 20
    pdf.chunk_new_line
    pdf.chunk "line two", :size => 20
    pdf.chunk_new_line
    pdf.chunk "line three", :size => 20
    pdf.chunk_new_line
    pdf.chunk "line four", :size => 20
  end
  pdf.stroke_bounds
end
pdf.text "below bb with height"

pdf.y -= 50
pdf.text "above bb without height"
pdf.bounding_box([0, pdf.cursor], :width => 200) do
  pdf.chunk_flow do
    pdf.chunk "line one", :size => 24
    pdf.chunk_new_line
    pdf.chunk "line two", :size => 24
    pdf.chunk_new_line
    pdf.chunk "line three", :size => 24
    pdf.chunk_new_line
    pdf.chunk "line four", :size => 24
  end
  #pdf.stroke_bounds
end
pdf.text "below bb without height"

pdf.y -= 50
pdf.chunk_flow do
  pdf.chunk "one two three ", :font_family => 'Courier'
  pdf.chunk "superscript"
  pdf.chunk_move_up 4
  pdf.chunk "TM", :size => 8
  pdf.chunk_move_down 4
  pdf.chunk_image "checkbox_checked.png", :width => 12, :height => 12
  pdf.chunk " aardvark bat cat dog egret fox", :style => :italic
  pdf.chunk "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus blandit semper elit et scelerisque. Ut pretium, ligula vitae ullamcorper malesuada, dui arcu faucibus enim, vel blandit nulla ante et dolor. Aenean ornare consequat nunc in luctus. Quisque eu pellentesque nulla. Curabitur viverra lobortis tellus ac suscipit. Quisque sagittis pellentesque leo, id scelerisque tortor consequat a. Nunc felis mi, fermentum rutrum semper et, accumsan et felis. In dignissim, metus a mollis tempor, quam lectus lacinia mi, sed laoreet quam elit ut lectus. In rhoncus porta rutrum. Vestibulum in justo nisi, ut ornare nisl. Curabitur sed sapien sed nunc porta placerat ut vitae ante. Nunc sed velit id risus placerat luctus at suscipit est. Sed id libero ut turpis laoreet fringilla. Suspendisse sit amet urna lectus. Maecenas vehicula convallis bibendum. Nam euismod ligula sit amet magna molestie vel semper eros aliquet. Aliquam erat volutpat. Pellentesque ut dui et purus ultricies dignissim."
  pdf.chunk "big", :size => 14
  pdf.chunk "bigger", :size => 20
  pdf.chunk "biggest", :size => 24
  pdf.chunk "normal. "
  text = "This line is drawn in a rainbow of beautiful colors"
  i = 0
  (3..12).step(2) do |r|
    (3..12).step(2) do |g|
      (3..12).step(2) do |b|
        hex = '%x' % r*2 + '%x' % g*2 + '%x' % b*2
        break if (i > text.size)
          pdf.chunk text[i,1], :color => hex, :no_space => (text[i + 1, 1] != ' ')
        i += 1
      end
    end
  end
end
pdf.text "this is bottom text"
pdf.render_file("chunktest.pdf")
