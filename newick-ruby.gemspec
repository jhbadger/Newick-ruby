Gem::Specification.new do |s|
  s.name = %q{newick-ruby}
  s.version = "1.0.0"
  s.date = %q{2010-07-26}
  s.authors = ["Jonathan Badger"]
  s.email = %q{jhbadger@gmail.com}
  s.summary = %q{newick-ruby provides routines for parsing newick-format phylogenetic trees.}
  s.homepage = %q{http://github.com/jhbadger/Newick-ruby}
  s.description = %q{newick-ruby provides routines for parsing newick-format phylogenetic trees.}
  s.add_dependency("fpdf", ">= 1.5.3")
  s.files = ["example/jgi_19094_1366.m000227-Phatr2.tree", "lib/Newick.rb", 
    "bin/newickAlphabetize", "bin/newickCompare", "bin/newickDist", "bin/newickDraw", 
    "bin/newickReorder", "bin/newickReroot", "bin/newickTaxa", "README", "test/tc_Newick.rb"]
  s.executables = ["newickAlphabetize", "newickCompare", "newickDist", "newickDraw", 
    "newickReorder", "newickReroot", "newickTaxa"]
  s.test_files=["test/tc_Newick.rb"]
end
