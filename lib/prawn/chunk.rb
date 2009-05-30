

module Prawn
  class Document
    #module Chunk


    # A wrapper for all 'chunk' api calls. Can be contained by the
    # document, a bounding_box, or a span.
    #
    # options:
    # * font_family - default font family name for contents
    # * style - default font style for contents
    # * size - default font size for contents
    # * color - default text color for contents
    # * background_color - background fill color behind text box
    def chunk_flow(options={})
      Prawn.verify_options [:font_family, :style, :size, :color, :background_color], options
      
      @chunk_data = {}
      chunk_save_state
      @chunk_line_queue = ChunkLineQueue.new unless @chunk_line_queue
      @chunk_line_queue.default_options(self, options)
      # bounding boxes with no height have their origin at the top left, all
      # other bounding boxes have there origin at the bottom left. We use
      # :direction to compensate.
      @chunk_data[:direction] = bounds.height ? 1 : -1
      @chunk_data[:x] = 0
      @chunk_data[:right_margin] = bounds.width
      @chunk_data[:left_margin] = 0
      @chunk_data[:y] = cursor
      @chunk_data[:origin] = [0, cursor]
      @chunk_line_queue.set_y cursor
      @chunk_line_queue.newline # start of first line
      chunk_check_page_break
      yield
      chunk_new_line unless @chunk_line_queue.empty?
      fill_box(options[:background_color]) if options[:background_color]
      @chunk_line_queue.flush(self)
      @chunk_line_queue.reset_options  
      self.y = @chunk_data[:y] + bounds.absolute_bottom
      chunk_restore_state
    end

    # An inline chunk of text
    #
    # options:
    # * font_family - default font family name for chunk
    # * style - default font style for chunk
    # * size - default font size for chunk
    # * color - default text color for chunk
    # * no_space - do not add spaces between words
    def chunk(text, options={})
      text = text.to_s.dup
      Prawn.verify_options [:font_family, :style, :size, :color, :no_space], options
      
      @chunk_line_queue.options(self, options) if (options.size > 0)
      @chunk_line_queue.set_x @chunk_data[:x]
      #@chunk_line_queue.set_y @chunk_data[:y]

      f = @chunk_line_queue.current_font
      size = @chunk_line_queue.current_options[:size]
      word_space = f.width_of(' ', :size => size, :kerning => f.has_kerning_data?)
      lines = text.split(/\n/)
      first_word = true
      lines.each_with_index do |line, i|
        line.split(/\s/).each do |word|
          width = f.width_of(word, :size => size, :kerning => f.has_kerning_data?)
          if ((@chunk_data[:x] + width > @chunk_data[:right_margin]) && (@chunk_data[:x] > @chunk_data[:left_margin]))
            chunk_new_line
          else
            word = " " + word unless (options[:no_space] || first_word)
            first_word = false
          end
          @chunk_line_queue.text(word)
          @chunk_data[:x] += width
          @chunk_data[:x] += word_space unless options[:no_space]
          if (i + 1 < lines.length)
            chunk_new_line
          end
        end
      end
      @chunk_line_queue.reset_options
    end

    # add an inline image
    #
    # options:
    # * width - width of image (required for now)
    # * height - height of image (required for now)
    # * all other prawn image options except for <b>at</b>
    def chunk_image(name, options={})
      options = options.merge({:at => [@chunk_data[:x], @chunk_data[:y]]})
      @chunk_line_queue.image(name, options)
      @chunk_data[:x] += options[:width]
    end

    # move cursor left
    def chunk_move_left(dx)
      @chunk_data[:x] -= dx
      @chunk_data[:x] = 0 if @chunk_data[:x] < 0
      @chunk_line_queue.move_x(-dx)
    end

    # move cursor right
    def chunk_move_right(dx)
      @chunk_data[:x] += dx
      @chunk_line_queue.move_x(dx)
    end

    # move cursor down
    def chunk_move_down(dy)
      @chunk_data[:y] -= dy*@chunk_data[:direction]
      @chunk_line_queue.move_y(-dy*@chunk_data[:direction])
    end

    # move cursor up
    def chunk_move_up(dy)
      @chunk_data[:y] += dy*@chunk_data[:direction]
      @chunk_line_queue.move_y(dy*@chunk_data[:direction])
    end

    # get/set left margin
    def chunk_left_margin(pad=nil)
      if (pad)
        @chunk_data[:x] = pad if (pad > @chunk_data[:x])
        @chunk_data[:left_margin] = pad
      end
      @chunk_data[:left_margin]
    end

    # get/set right margin
    def chunk_right_margin(pad=nil)
      @chunk_data[:right_margin] = pad if pad
      @chunk_data[:right_margin]
    end

    # move to next line
    def chunk_new_line     
      ascent, height = @chunk_line_queue.line_ascent_and_height
      @chunk_line_queue.prev_newline_move_y(-ascent)
      @chunk_data[:x] = @chunk_data[:left_margin]
      @chunk_data[:y] -= height * @chunk_data[:direction]
      chunk_check_page_break
      @chunk_line_queue.newline
      @chunk_line_queue.move_y ascent - height
      @chunk_line_queue.set_x @chunk_data[:left_margin]
    end

    
    def chunk_data #:nodoc:
      @chunk_data
    end

    private

    def chunk_check_page_break
      if (@chunk_data[:y] + bounds.absolute_bottom < margin_box.absolute_bottom)
        @chunk_line_queue.new_page
        @chunk_data[:y] = bounds.top
        @chunk_line_queue.set_x @chunk_data[:left_margin]
        @chunk_line_queue.set_y @chunk_data[:y]
      end
    end

    def chunk_save_state
      @chunk_data[:orig_color] = fill_color
      @chunk_data[:orig_font] = font
      @chunk_data[:orig_size] = font_size
    end

    def chunk_restore_state
      fill_color @chunk_data[:orig_color]
      set_font @chunk_data[:orig_font], @chunk_data[:orig_size]
    end

    def fill_box(color)
      old_fill_color = fill_color
      fill_color color
      fill_rectangle(@chunk_data[:origin], bounds.width, @chunk_data[:origin][1] - @chunk_data[:y])
      fill_color old_fill_color
    end
  end


  
  class ChunkLineQueue #:nodoc:
    def initialize
      @queue = []
    end

    # set default font options for content
    def default_options(document, options)
      options = {
        :font_family => document.font.family,
        :style => :normal,
        :size => document.font_size,
        :color => document.fill_color
      }.merge(options)
      @default_options = expand_options(document, options)
      @queue << @default_options
    end

    # override default options
    def options(document, options)
      options = @default_options.merge(options)
      new_options = expand_options(document, options)
      
      if (@default_options != new_options)
        if (@queue.last[:action] == :options)
          @queue[@queue.size - 1] = new_options
        else
          @queue << new_options
        end
      end
    end

    # restore default options
    def reset_options
      @queue << @default_options if (current_options != @default_options)
    end

    # return current options
    def current_options
      last_options = nil
      @queue.reverse_each do |item|
        if (item[:action] == :options)
          last_options = item
          break;
        end
      end
      last_options || @default_options
    end

    # return current font
    def current_font
      current_options[:font]
    end

    # return ascent and height of current line of text
    def line_ascent_and_height
      max_height = 0
      max_ascent = 0
      @queue.reverse_each do |item|
        if (item[:action] == :options)
          max_height = item[:height] if max_height < item[:height]
          max_ascent = item[:ascent] if max_ascent < item[:ascent]
        elsif (item[:action] == :newline)
          break;
        end
      end
      options = current_options
      [ (max_ascent > 0) ? max_ascent :  options[:ascent], (max_height > 0) ? max_height : options[:height] ]
    end

    # is the queue empty
    def empty?
      @queue.empty?
    end

    # add text element to queue
    def text(text)
      if (@queue.last[:action] == :text)
        @queue.last[:text] << text
      else
        @queue << {:action => :text, :text => text}
      end
    end

    # add x position to queue
    def set_x(x)
      @queue << {:action => :set_x, :x => x}
    end

    # add y position to queue
    def set_y(y)
      @queue << {:action => :set_y, :y => y}
    end

    # add delta x position to queue
    def move_x(x)
      @queue << {:action => :move_x, :x => x}
    end

    # add delta y position to queue
    def move_y(y)
      @queue << {:action => :move_y, :y => y}
    end

    # add a delta y position to the beginning of the current line of text
    def prev_newline_move_y(y)
      index = @queue.rindex({:action => :newline})
      if index
        index += 1
      else
        index = 0
      end
      @queue.insert(index, {:action => :move_y, :y => y})
    end

    # add and image element to the queue
    def image(name, options)
      @queue << {:action => :image, :name => name, :options => options}
    end

    # add a newline element to the queue
    def newline
      @queue << {:action => :newline}
    end

    # add a new page element to the queue
    def new_page
      @queue << {:action => :new_page}
    end

    # dump the queue for debugging
    def print_queue
      @queue.each do |item|
        print "#{item[:action]}\t#{item.inspect}\n"
      end
    end

    # flush the queue to the pdf document
    def flush(document)
      print "---flush\n" if $ChunkDebug
      print_queue if $ChunkDebug
      x = document.chunk_left_margin
      y = 0
      print "---flush y = #{y}\n" if $ChunkDebug
      @queue.each do |item|
        case item[:action]
        when :options
          document.fill_color item[:color]
          document.font item[:font_name], :size => item[:size]
        when :set_x
          x = item[:x]
        when :set_y
          y = item[:y]
        when :move_x
          x += item[:x]
        when :move_y
          y += item[:y]
        when :newline
          ;
        when :new_page
          document.start_new_page
        when :text
          document.text item[:text], :at => [x, y]
        when :image
          document.image item[:name], item[:options]
        end
      end
      @queue.clear
    end

    private

    # precompute varous font attributes
    def expand_options(document, options)
      family = options[:font_family]
      style = options[:style]
      font_name = document.font_families[family][style]
      f = document.find_font(font_name)
      current_size = document.font_size
      document.font_size = options[:size]
      new_options = {
        :action => :options,
        :font => f,
        :font_name => font_name,
        :font_family => family,
        :style => style,
        :color => options[:color],
        :size => options[:size],
        :height => f.height,
        :ascent => f.ascender
      }
      document.font_size = current_size
      return new_options
    end
  end

  

end

