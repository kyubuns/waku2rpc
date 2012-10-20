# coding: utf-8
import yaml
from jinja2 import FileSystemLoader, Environment
import os
import sha
import sys
import random
import codecs

# sha1
def hashfile(fileName, hashObject):
  fileObject = open(fileName, 'rb')
  try:
    while True:
      chunk = fileObject.read(65536)
      if not chunk: break
      hashObject.update(chunk)
  finally:
    fileObject.close()
  return hashObject.hexdigest()

def sha1file(fileName):
  hashObject = sha.new()
  return hashfile(fileName, hashObject)

#custom filters
def cast_hx(value, arg_type):
  if arg_type == 'Int' or arg_type == 'Float' or arg_type == 'Bool':
    return "cast(" + value + ", " + arg_type + ")"
  elif arg_type == 'String':
    return "Sanitizer.run(cast(" + value + ", " + arg_type + "))"
  else:
    return arg_type + ".create(" + value + ")"

def is_class(v):
  if v == 'int' or v == 'double' or v == 'bool' or v == 'string':
    return False
  return True

def to_arg(value):
  return "args[" + str(value) + "]"

#main
if __name__ == "__main__":
  if len(sys.argv) != 3:
    print 'usagee python generator.py [yuu_file] [output_filename]'
    quit(1)

  yuu_filename = sys.argv[1]
  output_filename = sys.argv[2]

  yuu = yaml.load(open(yuu_filename).read())
  env = Environment(loader=FileSystemLoader("."))
  env.filters['cast_hx'] = cast_hx
  env.filters['to_arg'] = to_arg
  env.tests['classname'] = is_class

  random.seed(sha1file(yuu_filename))
  random_ids = range(1000, 10000)
  random.shuffle(random_ids)

  lists = {}
  lists['C->S'] = []
  lists['S->C'] = []
  lists['struct'] = []
  lists['enum'] = []

  filetype = output_filename.split('.')[1];
  type_to = {}
  type_to['hpp'] = {
    'int':'int',
    'double':'double',
    'bool':'bool',
    'string':'std::string',
    'array':'std::vector',
  }
  type_to['hx'] = {
    'int':'Int',
    'double':'Float',
    'bool':'Bool',
    'string':'String',
    'array':'Array',
  }
  template_filename = {}
  template_filename['hpp'] = 'templates/wakuserver.hpp'
  template_filename['hx'] = 'templates/wakuclient.hx'

  #structは先に全部typeにつっこむ
  for name, args in yuu.items():
    if args[0]=='struct':
      type_to[filetype][name] = name;

  for name, args in yuu.items():
    type = args[0]
    output = {
      'name' : name,
      'type' : type,
      'id'   : random_ids[-1]
    }
    random_ids.pop()
    tmp = []
    for arg in args[1:]:
      if arg[1] == 'array':
        tmp.append({'name':arg[0], 'type':type_to[filetype]['array']+'<'+type_to[filetype][arg[2]]+'>', 'elementtype':type_to[filetype][arg[2]], 'is_array':True, 'originaltype':arg[2]})
      else:
        tmp.append({'name':arg[0], 'type':type_to[filetype][arg[1]], 'is_array':False, 'originaltype':arg[1]})
  
    output['args'] = tmp
    lists[type].append(output)

  template = env.get_template(os.path.join(os.path.dirname(__file__), template_filename[filetype]))
  f = open(output_filename, 'w')
  f = codecs.lookup('utf_8')[-1](f)
  f.write(template.render(
    CtoS       = lists['C->S'],
    StoC       = lists['S->C'],
    structs    = lists['struct'],
    enums      = lists['enum'],
    yuuversion = sha1file(yuu_filename)
    ))
  f.close()
