def is_ruby?
  __FILE__.match /.*.rb$/
end

def hash_from_key_value_array(array)
  array.map { |x| x[0] }.zip(array.map {|x| x[1]}).to_h
end

