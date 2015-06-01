require "Newick"
require "test/unit"

class TestNewickTree < Test::Unit::TestCase
  def test_to_s 
    tree = NewickTree.new("(A:0.65,(B:0.1,C:0.2)90:0.5);")
    assert_equal(tree.to_s(false, false), "(A,(B,C));")
    assert_equal(tree.to_s(true, false), "(A:0.65,(B:0.1,C:0.2):0.5);")
    assert_equal(tree.to_s, "(A:0.65,(B:0.1,C:0.2)90:0.5);")
  end
  def test_reorder
    tree = NewickTree.new("(B,(A,D),C);")
    assert_equal(tree.reorder.to_s, "((A,D),B,C);")
  end 
  def test_alias
    tree = NewickTree.new("((Apple,Pear),Grape);")
    aliTree, ali = tree.alias
    assert_equal(aliTree.to_s, "((SEQ0000001,SEQ0000002),SEQ0000003);")
    assert_equal(ali, {"SEQ0000001" => "Apple", "SEQ0000002" => "Pear", "SEQ0000003" => "Grape"})
  end
  def test_unAlias
    tree = NewickTree.new("(SEQ0000001, SEQ0000002, SEQ0000003);")
    ali = {"SEQ0000001" => "Frog", "SEQ0000002" => "Whale", "SEQ0000003" => "Kumquat"}
    assert_equal(tree.unAlias(ali).to_s, "(Frog,Whale,Kumquat);")
  end
  def test_taxa
    tree = NewickTree.new("(A:0.65,(B:0.1,C:0.2)90:0.5);")
    assert_equal(tree.taxa, ["A","B","C"])
  end
  def test_findNode
    tree = NewickTree.new("(A12,(A13,A2));")
    assert_equal(tree.findNode("A1", false).name, "A12")
    assert_equal(tree.findNode("A1", true), nil)
    assert_equal(tree.findNode("A13", true).name, "A13")
  end
end
