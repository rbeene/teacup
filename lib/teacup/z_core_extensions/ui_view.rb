# Teacup's UIView extensions defines some utility functions for UIView that
# enable a lot of the magic for Teacup::Layout.

# Users of teacup should be able to ignore the contents of this file for
# the most part.
class UIView
  include Teacup::Layout

  # The current stylename that is used to look up properties in the stylesheet.
  attr_reader :stylename

  # The current stylesheet will be looked at when properties are needed.  It
  # is loaded lazily, so that assignment can occur before the Stylesheet has
  # been created.
  def stylesheet
    if Symbol === @stylesheet
      @stylesheet = Teacup::Stylesheet[@stylesheet]
    end

    @stylesheet
  end

  # Alter the stylename of this view.
  #
  # This will cause new styles to be applied from the stylesheet.
  #
  # @param Symbol  stylename
  def stylename=(new_stylename)
    @stylename = new_stylename
    restyle!
  end

  # Alter the stylesheet of this view.
  #
  # This will cause new styles to be applied using the current stylename,
  # and will recurse into subviews.
  #
  # If you would prefer that a given UIView object does not inherit the
  # stylesheet from its parents, override the 'stylesheet' method to
  # return the correct value at all times.
  #
  # @param Teacup::Stylesheet  stylesheet.
  def stylesheet=(new_stylesheet)
    @stylesheet = new_stylesheet
    restyle!
    subviews.each{ |subview| subview.stylesheet = new_stylesheet }
  end

  def restyle!(orientation=nil)
    style(stylesheet.query(@stylename)) if @stylesheet
    subviews.each{ |subview| subview.restyle!(orientation) }
  end

  # Animate a change to a new stylename.
  #
  # This is equivalent to wrapping a call to .stylename= inside
  # UIView.beginAnimations.
  #
  # @param Symbol  the new stylename
  # @param Options  the options for the animation (may include the
  #                 duration and the curve)
  #
  def animate_to_stylename(stylename, options={})
    return if self.stylename == stylename

    UIView.beginAnimations(nil, context: nil)
    # TODO: This should be in a style-sheet!
    UIView.setAnimationDuration(options[:duration]) if options[:duration]
    UIView.setAnimationCurve(options[:curve]) if options[:curve]
    self.stylename = stylename
    UIView.commitAnimations
  end

  # Apply style properties to this element.
  #
  # Takes a hash of properties such as may have been read from a stylesheet
  # or passed as parameters to {Teacup::Layout#layout}, and applies them to
  # the element.
  #
  # Does a little bit of magic (that may be split out as 'sugarcube') to
  # make properties work as you'd expect.
  #
  # If you try and assign something in properties that is not supported,
  # a warning message will be emitted.
  #
  # @param Hash  the properties to set.
  def style(properties, orientation=nil)
    if stylesheet
      self.class.ancestors.each do |ancestor|
        if default_properties = stylesheet.query(ancestor)
          properties = default_properties.merge properties
        end
      end
    end

    # orientation-specific properties
    portrait = properties.delete(:portrait)
    upside_up = properties.delete(:upside_up)
    upside_down = properties.delete(:upside_down)

    landscape = properties.delete(:landscape)
    landscape_left = properties.delete(:landscape_left)
    landscape_right = properties.delete(:landscape_right)

    if orientation.nil?
      orientation = UIApplication.sharedApplication.statusBarOrientation
    end

    case orientation
    when UIInterfaceOrientationPortrait
      properties.update(portrait) if Hash === portrait
      properties.update(upside_up) if Hash === upside_up
    when UIInterfaceOrientationPortraitUpsideDown
      properties.update(portrait) if Hash === portrait
      properties.update(upside_down) if Hash === upside_down
    when UIInterfaceOrientationLandscapeLeft
      properties.update(landscape) if Hash === landscape
      properties.update(landscape_left) if Hash === landscape_left
    when UIInterfaceOrientationLandscapeRight
      properties.update(landscape) if Hash === landscape
      properties.update(landscape_right) if Hash === landscape_right
    end

    # convert top/left/width/height to frame values
    clean_properties properties

    if layer_properties = properties.delete(:layer)
      layer_properties.each do |key, value|
        assign = :"#{key}="
        setter = ('set' + key.to_s.sub(/^./) {|c| c.capitalize}).to_sym
        if layer.respond_to?(assign)
          # puts "Setting layer.#{key} = #{value.inspect}"
          layer.send(assign, value)
        elsif layer.respond_to?(setter)
          # puts "Calling layer(#{key}, #{value.inspect})"
          layer.send(setter, value)
      else
        puts "Teacup WARN: Can't apply #{key} to #{self.layer.inspect}"
        end
      end
    end

    properties.each do |key, value|
      assign = :"#{key}="
      setter = ('set' + key.to_s.sub(/^./) {|c| c.capitalize}).to_sym
      if key == :title && UIButton === self
        setTitle(value, forState: UIControlStateNormal)
      elsif respond_to?(assign)
        # puts "Setting #{key} = #{value.inspect}"
        send(assign, value)
      elsif respond_to?(setter)
        # puts "Calling self(#{key}, #{value.inspect})"
        send(setter, value)
      else
        puts "Teacup WARN: Can't apply #{key} to #{self.inspect}"
      end
    end
    self.setNeedsDisplay
  end

  # merge definitions for 'frame' into one.
  #
  # To support 'extends' more nicely it's convenient to split left, top, width
  # and height out of frame. Unfortunately that means we have to write ugly
  # code like this to reassemble them into what the user actually meant.
  #
  # WARNING: this method *mutates* its parameter.
  #
  # @param Hash
  # @return Hash
  def clean_properties(properties)
    return unless [:frame, :left, :top, :width, :height].any?(&properties.method(:key?))

    frame = properties.delete(:frame) || self.frame

    frame[0][0] = properties.delete(:left) || frame[0][0]
    frame[0][1] = properties.delete(:top) || frame[0][1]
    frame[1][0] = properties.delete(:width) || frame[1][0]
    frame[1][1] = properties.delete(:height) || frame[1][1]

    properties[:frame] = frame
    properties
  end

  def top_level_view
    return self
  end

end
