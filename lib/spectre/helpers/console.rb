# class String
#   @@colored = false

#   def self.colored!
#     @@colored = true
#   end

#   def white;   self; end
#   def red; colored '31'; end
#   def green; colored '32'; end
#   def yellow; colored '33'; end
#   def blue; colored '34'; end
#   def magenta; colored '35'; end
#   def cyan; colored '36'; end
#   def grey; colored '90'; end

#   alias ok green
#   alias error red
#   alias warn yellow
#   alias info blue
#   alias dim grey

#   def indent amount, char: ' '
#     self.lines.map { |line| char * amount + line }.join "\n"
#   end

#   def length
#     m = /\e\[\d{2}m(.*)\e\[0m/.match self
#     return self.chars.count - 9 if m
#     self.chars.count
#   end

#   def lines
#     self.split "\n"
#   end

#   private

#   def colored ansi_color
#     return self if !@@colored
#     "\e[#{ansi_color}m#{self}\e[0m"
#   end
# end


# class Object
#   def pretty width: nil
#     self.to_s
#   end
# end


# class TrueClass
#   def pretty width: nil
#     'yes'.green
#   end
# end


# class FalseClass
#   def pretty width: nil
#     'no'.yellow
#   end
# end


# class NilClass
#   def pretty width: nil
#     'n/a'.grey
#   end
# end


# class Array
#   def pretty width: 25
#     return 'empty'.grey if self.length == 0

#     list_length = self.map { |x| x.to_s.length }.reduce(:+)
#     return self.join ', ' if list_length && list_length < 30

#     self
#       .select { |x| x != nil && x != '' }
#       .map do |x|
#         ' - ' + x.pretty(width: width-3).strip.gsub(/\n/, "\n   ")
#       end
#       .join "\n"
#   end

#   def table header: nil, mappings: {}, with_index: false, limit: 50
#     header = self[0].keys if header == nil
#     heading = header.is_a?(Array) ? header : self[0].keys

#     table_data = self.slice(0, limit).map do |row|
#       heading.map do |key|
#         mappings.has_key?(key) ? mappings[key][row, row[key]] : row[key]
#       end
#     end

#     table_data.insert(0, heading) if header != false

#     data_sizes = table_data.map do |row|
#       row.map { |data| data.to_s.length }
#     end

#     column_sizes = data_sizes[0]
#       .zip(*data_sizes[1..-1])
#       .map { |row| row.max }

#     table = table_data.map { |row| column_sizes.zip row }

#     table_str = ''
#     table.each_with_index do |row, index|
#       if with_index
#         if index == 0
#           table_str += '     '
#         else
#           table_str += "[#{index}]  "
#         end
#       end

#       row.each do |col_size, data|
#         table_str += (data.to_s + ' ' * (col_size - data.to_s.length)) + '    '
#       end

#       table_str += "\n"
#     end
#     table_str += '[...]' if self.count > limit
#     print table_str
#   end
# end


# class Hash
#   def pretty indent: 0, width: 25
#     s = ''

#     self
#       .select { |key, value| value != nil || value != '' }
#       .map do |key, value|
#         value = true if value == 'true'
#         value = false if value == 'false'
#         value = '********' if /password|pwd|pass|passwd|secret/ =~ key.to_s

#         if value.is_a? Hash
#           s += key.to_s.cyan.indent(indent) + "\n"
#           s += value.pretty(width: width-indent-2).indent(indent+2)
#           s += "\n"
#           next
#         end

#         s += ' ' * indent

#         if value.is_a? Array
#           list = value.pretty(width: width)

#           if list.lines.count > 1
#             s += key.to_s.cyan + "\n"
#             s += value.pretty(width: width).indent(indent)
#             s += "\n"
#             next
#           end

#           value = list
#         end

#         s += key.to_s.cyan
#         s += ' ' + '.' * (width-key.to_s.length-indent) if width-key.to_s.length > indent
#         s += ': '
#         s += value.pretty + "\n"
#       end

#     s
#   end
# end


# class Float
#   def duration
#     seconds = self

#     if seconds > 60
#       seconds = seconds.to_i
#       minutes = seconds / 60
#       seconds = seconds % 60
#     end

#     if minutes && minutes > 60
#       hours = minutes / 60
#       minutes = minutes % 60
#     end

#     duration_str = "#{seconds}s"
#     duration_str = "#{minutes}m #{duration_str}" if minutes
#     duration_str = "#{hours}h #{duration_str}" if hours

#     duration_str
#   end
# end