# Exception raised when a parse error happens in processing a Newick tree
class NewickParseError < RuntimeError
end

# Represents a token (substring with meaning) in a Newick parse
class NewickToken
  # semantic meaning of token (label, weight, etc.)
  attr_reader :type
  # string value of token
  attr_reader :value
  
  def initialize(type, value)
    @type = type
    @value = value
  end

end


# Splits a Newick tree string into tokens that NewickTree uses
class NewickTokenizer
  
  def initialize(str)
    @str = str
    @pos = 0
  end

  # returns the next character in the string and updates position
  def nextChar
    if (@pos < @str.size)
      c = @str[@pos].chr
      @pos += 1
      return c
    else
      return nil
    end
  end

  # returns the next token in the string and updates position
  def nextToken
    c = nextChar
    if (c == " " || c == "\n" || c == "\r")
      return nextToken
    elsif (c == "(" || c == ")" || c == ',')
      return NewickToken.new("SYMBOL", c)
    elsif (c == ":")
      if (@str.index((/([0-9|\.|\-|e|E]+)/), @pos) == @pos)
	@pos += $1.length
	return NewickToken.new("WEIGHT", $1)
      else
	raise NewickParseError, "Illegal weight at pos #{@pos} of #{@str}"
      end
    elsif (c == "'")
      if (@str.index(/(\'[^\']*\')/, @pos - 1) == @pos - 1)
	@pos += $1.length - 1
	return NewickToken.new("LABEL", $1)
      else
	raise NewickParseError, "Illegal label at pos #{@pos} of #{@str}"
      end
    elsif (@str.index(/([^,():]+)/, @pos - 1) == @pos - 1)
      @pos += $1.length - 1
      return NewickToken.new("LABEL", $1)
    end
  end

  # returms the next token in the string without changing position
  def peekToken
    origPos = @pos
    token = nextToken
    @pos = origPos
    return token
  end

end

# Represents a single node in a NewickTree
class NewickNode
  # parent node of node
  attr :parent, true
  # edge length of node
  attr :edgeLen, true
  # name of node
  attr :name, true
  # child nodes of node
  attr_reader :children
  # x position of node
  attr :x, true
  # y position of node
  attr :y, true

  def initialize(name, edgeLen)
    @parent = nil
    @name = name
    @edgeLen = edgeLen
    @children = []
  end

  # adds child node to list of children and sets child's parent to self
  def addChild(child)
    child.parent = self
    @children.push(child)
  end

  # removes child node from list of children and sets child's parent to nil
  def removeChild(child)
    @children.delete(child)
    child.parent = nil
  end

  # returns string representation of node
  def to_s(showLen = true, bootStrap = "node")
    s = ""
    if (!leaf?)
      s += "("
      @children.each {|child|
	s += child.to_s(showLen, bootStrap)
	s += "," if (child != @children.last)
      }
      s += ")"
    end
    if (leaf? || bootStrap == "node")
      s += @name
    end
    s += ":#{@edgeLen}" if (showLen && @edgeLen != 0)
    if (!leaf? && name.to_i > 0 && bootStrap == "branch")
      s += ":#{name}"
    end
    return s
  end

  # returns array of names of leaves (taxa) that are contained in the node
  def taxa(bootstrap = false)
    taxa = []
    if (!leaf?)
      taxa.push(@name) if (bootstrap)
      @children.each {|child|
	child.taxa.each {|taxon|
	  taxa.push(taxon)
	}
      }
    else
      taxa.push(name)
    end
    return taxa.sort
  end
  
  # returns array of leaves (taxa) are contained in the node
  def leaves
    nodes = []
    descendants.each {|node|
      nodes.push(node) if (node.leaf?)
    }
    return nodes
  end

  # returns array of non leaves (taxa) that are contained in the node
  def intNodes
    nodes = []
    descendants.each {|child|
      nodes.push(child) if (!child.leaf?)
    }
    return nodes
  end

  # returns node with given name, or nil if not found
  def findNode(name)
    found = nil
    if (@name =~/#{name}/)
      found = self
    else
      @children.each {|child|
	found = child.findNode(name)
	break if found
      }
    end
    return found
  end

  # reverses the parent-child relationship (used in rerooting tree)
  def reverseChildParent
    return if (@parent.nil?)
    oldParent = @parent
    oldParent.removeChild(self)
    if (!oldParent.parent.nil?)
      oldParent.reverseChildParent
    end
    addChild(oldParent)
    oldParent.edgeLen = @edgeLen
    @edgeLen = 0
  end
  
  # True if given node is child (or grandchild, etc.) of self. False otherwise
  def include?(node)
    while(node.parent != nil)
      return true if (node.parent == self)
      node = node.parent
    end
    return false
  end

  # True if node has no children (and therefore is a leaf)
  def leaf?
    if (@children.empty?)
      return true
    else
      return false
    end
  end

  # returns array of all descendant nodes
  def descendants
    descendants = []
    @children.each {|child|
      descendants.push(child)
      child.descendants.each {|grandchild|
	descendants.push(grandchild)
      }
    }
    return descendants
  end

  # return array of all sibling nodes
  def siblings
    siblings = []
    if (parent.nil?)
      return siblings
    else
      @parent.children.each {|child|
        siblings.push(child) if (child!=self)
      }
      return siblings
    end
  end

 # reorders descendant nodes alphabetically and by size
  def reorder
    return if (@children.empty?)
    @children.sort! {|x, y| x.name <=> y.name}
    @children.each {|child|
      child.reorder
    }
    return self
  end

  

  # returns the last common ancestor node of self and given node
  def lca(node)
    if (self.include?(node))
      return self
    elsif (node.include?(self))
      return node
    else
      return @parent.lca(node)
    end
  end

  # returns the distance to the ancestor node
  def distToAncestor(ancestor)
    dist = 0
    node = self
    while(node != ancestor)
      dist += node.edgeLen
      node = node.parent
    end
    return dist
  end
  

  # returns number of nodes to the ancestor node
  def nodesToAncestor(ancestor)
    if (!ancestor.include?(self))
      return nil
    elsif (ancestor == self)
      return 0
    elsif (ancestor == @parent)
      return 1
    else
      return 1 + @parent.nodesToAncestor(ancestor)
    end
  end

  
  # returns number of nodes to other node
  def nodesToNode(node)
    lca = lca(node)
    if (lca == self)
      return node.nodesToAncestor(self)
    elsif (lca == node)
      return nodesToAncestor(node)
    else
      return nodesToAncestor(lca) + node.nodesToAncestor(lca)
    end
  end

  # calculates node Y positions
  def calcYPos
    ySum = 0
    @children.each {|child|
      ySum += child.y
    }
    @y = ySum / @children.size
  end

  # calculates node X positions
  def calcXPos
    if (parent.nil?)
      @x = 0
    else
      #@edgeLen = 1 if (@edgeLen == 0)
      @x = parent.x + @edgeLen
    end
    if (!leaf?)
      @children.each {|child|
        child.calcXPos
      }
    end
  end

  # returns the maximum X value in node
  def xMax
    xMax = 0
    children.each {|child|
      xMax = child.edgeLen if (child.x > xMax)
    }
    return xMax
  end

  # returns the maximum Y value in node
  def yMax
    yMax = 0
    children.each {|child|
      yMax = child.y if (child.y > yMax)
    }
    return yMax
  end

  # returns the minimum Y value in node
  def yMin
    yMin = 1e6
    children.each {|child|
      yMin = child.y if (child.y < yMin)
    }
    return yMin
  end

end

class NewickTree
  attr_reader :root
  def initialize(treeString)
    tokenizer = NewickTokenizer.new(treeString)
    @root = buildTree(nil, tokenizer)
  end

  # create new NewickTree from tree stored in file
  def NewickTree.fromFile(fileName)
    treeString = ""
    inFile = File.new(fileName)
    inFile.each {|line|
      treeString += line.chomp
    }
    inFile.close
    treeString.gsub!(/\[[^\]]*\]/,"") # remove comments before parsing
    return NewickTree.new(treeString)
  end

  # internal function used for building tree structure from string
  def buildTree(parent, tokenizer)
    while (!(token = tokenizer.nextToken).nil?)
      if (token.type == "LABEL")
	name = token.value
	edgeLen = 0
	if (tokenizer.peekToken.type == "WEIGHT")
	  edgeLen = tokenizer.nextToken.value.to_f
	end
	node = NewickNode.new(name, edgeLen)
	return node
      elsif (token.value == "(")
	node = NewickNode.new("", 0)
	forever = true
	while (forever)
	  child = buildTree(node, tokenizer)
	  node.addChild(child)
	  break if tokenizer.peekToken.value != ","
	  tokenizer.nextToken
	end
	if (tokenizer.nextToken.value != ")")
	  raise NewickParseError, "Expected ')' but found: #{token.value}"
	else
	  peek = tokenizer.peekToken
	  if (peek.value == ")" || peek.value == "," || peek.value == ";")
	    return node
	  elsif (peek.type == "WEIGHT")
	    node.edgeLen = tokenizer.nextToken.value.to_f
	    return node
	  elsif (peek.type == "LABEL")
	    token = tokenizer.nextToken
	    node.name = token.value
	    if (tokenizer.peekToken.type == "WEIGHT")
	      node.edgeLen = tokenizer.nextToken.value.to_f
	    end
	    return node
	  end
	end 
      else
	raise NewickParseError, 
	  "Expected '(' or label but found: #{token.value}"
      end
    end
  end

  # return string representation of tree
  def to_s(showLen = true, bootStrap = "node")
    return @root.to_s(showLen, bootStrap) + ";"
  end

  # write string representation of tree to file
  def write(fileName, showLen = true, bootStrap = "node")
    file = File.new(fileName, "w")
    file.print @root.to_s(showLen, bootStrap) + ";\n"
    file.close
  end

  # reorders leaves alphabetically and size
  def reorder
    @root.reorder
    return self
  end

  # renames nodes and creates an alias file, returning aliased tree and hash
  def alias(aliasFile = nil, longAlias = false)
    ali = Hash.new
    aliF = File.new(aliasFile, "w") if (!aliasFile.nil?)
    if (longAlias)
      taxon = "SEQ" + "0"* taxa.sort {|x,y| x.length <=> y.length}.last.length
    else
      taxon =  "SEQ0000001"
    end
    @root.descendants.each {|node|
      if (node.name != "" && node.name.to_i == 0)
	ali[taxon] = node.name
	aliF.printf("%s\t%s\n", taxon, node.name) if (!aliasFile.nil?)
	node.name = taxon.dup
	taxon.succ!
      end
    }
    aliF.close if (!aliasFile.nil?)
    return self, ali
  end

  # renames nodes according to alias hash
  def unAlias(aliasNames)
    @root.descendants.each {|node|
      node.name = aliasNames[node.name] if (!aliasNames[node.name].nil?)
    }
    return self
  end

  # renames nodes according to inverse alias hash 
  def reAlias(aliasNames)
    @root.descendants.each {|node|
      aliasNames.keys.each {|key|
        node.name = key if (aliasNames[key] == node.name)
      }
    }
    return self
  end

  # return array of all taxa in tree
  def taxa
    return @root.taxa
  end

  # returns a 2D hash of pairwise distances on tree
  def distanceMatrix
    dMatrix = Hash.new
    @root.taxa.each {|taxon1|
      dMatrix[taxon1] = Hash.new
      taxon1Node = @root.findNode(taxon1)
      @root.taxa.each {|taxon2|
	if (taxon1 == taxon2)
	  dMatrix[taxon1][taxon2] = 0.0
	else
	  taxon2Node = @root.findNode(taxon2)
	  lca = taxon1Node.lca(taxon2Node)
	  dMatrix[taxon1][taxon2] = taxon1Node.distToAncestor(lca) + 
	    taxon2Node.distToAncestor(lca)
	end
      }
    }
    return dMatrix
  end

  # returns lists of clades different between two trees
  def compare(tree)
    tree1 = self.dup.unroot
    tree2 = tree.dup.unroot
    
    diff1 = []
    diff2 = []
    if (tree1.taxa == tree2.taxa)
      clades1 = tree1.clades
      clades2 = tree2.clades
      clades1.each {|clade|
	if (!clades2.include?(clade))
	  diff1.push(clade)
	end
      }
      clades2.each {|clade|
	if (!clades1.include?(clade))
	  diff2.push(clade)
	end
      }
    else
      raise NewickParseError, "The trees have different taxa!"
    end
    return diff1, diff2
  end

  # return node with the given name
  def findNode(name)
    return @root.findNode(name)
  end

  # unroot the tree
  def unroot
    if (@root.children.size != 2)
      return self # already unrooted
    end
    left, right = @root.children
    left, right = right, left if (right.leaf?) # don't uproot leaf side   
    left.edgeLen += right.edgeLen
    right.children.each {|child|
      @root.addChild(child)
    }
    @root.removeChild(right)
    return self
  end

  # root the tree on a given node
  def reroot(node)
    unroot
    left = node
    right = left.parent
    right.removeChild(node)
    right.reverseChildParent
    if (left.edgeLen != 0)
      right.edgeLen = left.edgeLen / 2.0
      left.edgeLen = right.edgeLen
    end
    @root = NewickNode.new("", 0)
    @root.addChild(left)
    @root.addChild(right)
    return self
  end

  # returns the two most distant leaves and their distance apart
  def mostDistantLeaves
    greatestDist = 0
    dist = Hash.new
    org1, org2 = nil, nil
    @root.leaves.each {|node1|
      @root.leaves.each {|node2|
        dist[node1] = Hash.new if dist[node1].nil?
        dist[node2] = Hash.new if dist[node2].nil?
        next if (!dist[node1][node2].nil?)
        lca = node1.lca(node2)
        dist[node1][node2] = node1.distToAncestor(lca) + 
                                node2.distToAncestor(lca)
        dist[node2][node1] = dist[node1][node2]
        if (dist[node1][node2] > greatestDist)
          org1 = node1
          org2 = node2
          greatestDist = dist[node1][node2]
	end
      }
    }
    return org1, org2, greatestDist
  end

  # add EC numbers from alignment
  def addECnums(alignFile)
    ec = Hash.new
    File.new(alignFile).each {|line|
      if (line =~ /^>/)
	definition = line.chomp[1..line.length]
	name = definition.split(" ").first
	if (definition =~ /\[EC:([0-9|\.]*)/)
	  ec[name] = name + "_" + $1
	end
      end
    }
    unAlias(ec)
  end

  # root the tree on midpoint distance
  def midpointRoot
    unroot
    org1, org2, dist = mostDistantLeaves
    midDist = dist / 2.0
    return self if (midDist == 0)
    if (org1.distToAncestor(@root) > org2.distToAncestor(@root))
      node = org1
    else
      node = org2
    end
    distTraveled = 0
    while(!node.nil?)
      distTraveled += node.edgeLen
      break if (distTraveled >= midDist)
      node = node.parent
    end
    oldDist = node.edgeLen
    left, right = node, node.parent
    right.removeChild(node)
    right.reverseChildParent
    left.edgeLen = distTraveled - midDist
    right.edgeLen = oldDist - left.edgeLen
    @root = NewickNode.new("", 0)
    @root.addChild(left)
    @root.addChild(right)
    return self
  end

  # returns array of arrays representing the tree clades
  def clades(bootstrap = false)
    clades = []
    @root.descendants.each {|clade|
      clades.push(clade.taxa(bootstrap)) if (!clade.children.empty?)
    }
    return clades
  end

  # add bootstrap values (given in clade arrays) to a tree
  def addBootStrap(bootClades)
    @root.descendants.each {|clade|
      next if clade.leaf?
      bootClades.each {|bClade|
	boot, rest = bClade.first, bClade[1..bClade.size - 1]
	if (rest == clade.taxa ) # same clade found
	  clade.name = boot
	end
      }
    }
  end

  # return array of arrays of taxa representing relatives at each level
  def relatives(taxon)
    node = findNode(taxon)
    if (node.nil?)
      return nil
    else
      relatives = []
      while(!node.parent.nil?)
	relatives.push(node.parent.taxa - node.taxa)
	node = node.parent
      end
      return relatives
    end
  end

  
  # Fixes PHYLIP's mistake of using branch lengths and not node values
  def fixPhylip
    @root.descendants.each {|child|
      br = child.edgeLen.to_i
      child.edgeLen = 0
      if (br > 0 && !child.leaf?)
        child.name = br.to_s
      end
    }
  end


  # calculates leaf node positions (backwards from leaves, given spacing)
  def calcPos(yUnit)
    yPos = 0.25
    @root.reorder
    leaves = @root.leaves.sort {|x, y| x.nodesToNode(y) <=> y.nodesToNode(x)}
    leaves.each {|leaf|
      leaf.y = yPos
      yPos += yUnit
    }
    nodes =  @root.intNodes.sort{|x, y| y.nodesToAncestor(@root) <=> 
                                       x.nodesToAncestor(@root)}
    nodes.each {|node|
      node.calcYPos
    }
    @root.calcYPos
    @root.calcXPos
    nodes =  @root.intNodes.sort{|x, y| x.nodesToAncestor(@root) <=> 
                                       y.nodesToAncestor(@root)}
    nodes.each {|node|
      @root.calcXPos # (forwards from root)
    }
  end

  # function to generate gi link to ncbi for draw, below
  def giLink(entry)
    ncbiLink = "http://www.ncbi.nlm.nih.gov/entrez/"
    protLink = "viewer.fcgi?db=protein&val="
    if (entry =~ /^gi[\_]*([0-9]*)/ || entry =~ /(^[A-Z|0-9]*)\|/)
      return ncbiLink + protLink + $1
    else
      return nil
    end
  end
  
  # returns PDF representation of branching structure of tree
  def draw(pdfFile, boot="width", linker = :giLink, labelName = false,
	   highlights = Hash.new, brackets = nil, rawNames = false)
    pdf=FPDF.new('P', "cm")
    pdf.SetTitle(pdfFile)
    pdf.SetCreator("newickDraw")
    pdf.SetAuthor(ENV["USER"]) if (!ENV["USER"].nil?)
    pdf.AddPage
    yUnit = nil
    lineWidth = nil
    fontSize = nil
    bootScale = 0.6
    if (taxa.size < 30)
      fontSize = 10
      yUnit = 0.5
      lineWidth = 0.02
    elsif (taxa.size < 60)
      fontSize = 8
      yUnit = 0.25
      lineWidth = 0.01
    elsif (taxa.size < 150)
      fontSize = 8
      yUnit = 0.197
      lineWidth = 0.01
    elsif (taxa.size < 300)
      fontSize = 2
      yUnit = 0.09
      lineWidth = 0.005
    elsif (taxa.size < 400)
      fontSize = 2
      yUnit = 0.055
      lineWidth = 0.002
    elsif (taxa.size < 800)
      fontSize = 1
      yUnit = 0.030
      lineWidth = 0.0015
    else
      fontSize = 0.5
      yUnit = 0.020
      lineWidth = 0.0010
    end
    bootScale = 0.5 * fontSize
    pdf.SetFont('Times','B', fontSize)
    calcPos(yUnit) # calculate node pos before drawing
    max = 0
    @root.leaves.each {|leaf|
      d = leaf.distToAncestor(@root)
      max = d if (max < d)
    }
    xScale = 10.0/max
    xOffSet = 0.25
    pdf.SetLineWidth(lineWidth)
    pdf.SetTextColor(0, 0, 0)
    pdf.Line(0, @root.y, xOffSet, @root.y)
    pdf.Line(xOffSet, @root.yMin, xOffSet, @root.yMax)
    @root.descendants.each {|child|
      if (!child.leaf?)
        if (child.name.to_i > 75 && boot == "width") # good bootstrap
          pdf.SetLineWidth(lineWidth * 5)
        else
          pdf.SetLineWidth(lineWidth)
        end
	      bootX = xOffSet + child.x*xScale 
	      bootY = ((child.yMin + child.yMax) / 2.0) 
	      pdf.SetXY(bootX, bootY) 
	      pdf.SetFont('Times','B', bootScale)
	      pdf.Write(0, child.name.to_s)
	      pdf.SetFont('Times','B', fontSize)
        pdf.Line(xOffSet + child.x*xScale, child.yMin, 
          xOffSet + child.x*xScale, child.yMax)
      else
        if (child.parent.name.to_i > 75 && boot == "width") # good bootstrap
          pdf.SetLineWidth(lineWidth * 5)
        else
          pdf.SetLineWidth(lineWidth)
        end
        pdf.SetXY(xOffSet + child.x*xScale, child.y)
	      efields = child.name.split("__")
        entry, species = efields.first, efields.last
	      if (entry =~/\{([^\}]*)\}/)
	        species = $1
	      end
        species = entry if species.nil? && !rawNames
        species = child.name if rawNames
	      hl = false
	      highlights.keys.each{|highlight|
	        hl = highlights[highlight] if (entry.index(highlight))
	      } 
        if (pdfFile.index(entry)) # name of query taxon
          pdf.SetTextColor(255,0, 0) # red
          pdf.Write(0, entry) 
          pdf.SetTextColor(0, 0, 0) # black
        elsif (linker && link = send(linker, entry)) 
	        pdf.SetTextColor(255,0, 0) if hl # red
	        pdf.Write(0, species, link)
	        pdf.SetTextColor(0, 0, 0) if hl # black 
        elsif (!species.nil?)
          pdf.SetTextColor(hl[0],hl[1], hl[2]) if hl 
          pdf.Write(0, species) 
          pdf.SetTextColor(0, 0, 0) if hl # black 
        else
          pdf.SetTextColor(hl[0],hl[1], hl[2]) if hl # red
          pdf.Write(0, entry) 
          pdf.SetTextColor(0, 0, 0) if hl # black 
        end
      end
      pdf.Line(xOffSet + child.parent.x*xScale, child.y, 
        xOffSet + child.x*xScale, child.y)
      }
      if (labelName)
        pdf.SetFont('Times','B', 24)
        pdf.SetXY(0, pdf.GetY + 1)
        pdf.Write(0, File.basename(pdfFile,".pdf"))
      end
      if (brackets)
        brackets.each {|bracket|
          x, y1, y2, label, r, p = bracket
          next if label.nil?
          pdf.SetLineWidth(lineWidth * 5)
          pdf.SetFont('Times','B', fontSize*1.5)
          pdf.Line(x, y1, x, y2)
          pdf.Line(x, y1, x - 0.3, y1)
          pdf.Line(x, y2, x - 0.3, y2)
          pdf.SetXY(x, (y1+y2)/2)
          pdf.Write(0, label)
          if (r == "r")
            pdf.SetTextColor(255, 0, 0) 
            pdf.SetXY(x + 1.8, -0.65+(y1+y2)/2)
            pdf.SetFont('Times','B', fontSize*10)
            pdf.Write(0, " .")
            pdf.SetTextColor(0, 0, 0)
          end
          if (p == "p" || r == "p")
            pdf.SetTextColor(255, 0, 255) 
            pdf.SetXY(x + 2.3, -0.65+(y1+y2)/2)
            pdf.SetFont('Times','B', fontSize*10)
            pdf.Write(0, " .")
            pdf.SetTextColor(0, 0, 0)
          end
        }
      end
      pdf.SetLineWidth(lineWidth * 5)
      pdf.Line(1, pdf.GetY + 1, 1 + 0.1*xScale, pdf.GetY + 1) 
      pdf.SetFont('Times','B', fontSize)
      pdf.SetXY(1 + 0.1*xScale, pdf.GetY + 1)
      pdf.Write(0, "0.1")
      if (pdfFile =~/^--/)
        return pdf.Output
      else
        pdf.Output(pdfFile)
    end
  end
end



