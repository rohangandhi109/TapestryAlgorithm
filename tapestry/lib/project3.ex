defmodule Tapestry do
  def start() do
    [numNodes, numRequest] = System.argv()
    numNodes = String.to_integer(numNodes)-1   # we are creating first 99 nodes and then other 1 node via dynamic insertion
    numRequest = String.to_integer(numRequest)

    :ets.new(:processTable,[:set,:public,:named_table])
    :ets.new(:network,[:set,:public,:named_table])
    :ets.new(:hopCount,[:set,:public,:named_table])
    #ets table to store list of process and its hashID {key,value}->{hashID,pid}

    :ets.insert(:hopCount,{"maxHop",0})
    #IO.puts("Starting Nodes...")
    temp=Enum.reduce(1..numNodes,[],fn(x,hashList)->
      hashID = :crypto.hash(:sha,Integer.to_string(x))|>Base.encode16 |>String.slice(0..7)
      Server.start_link([hashID,[],0])  # 0 is max hop initially
      hashList++[hashID]
    end)
    #IO.puts("Building Routing Tables...")
    Enum.each(1..numNodes, fn(x)->
      hashID = :crypto.hash(:sha,Integer.to_string(x))|>Base.encode16 |>String.slice(0..7)
      pid = Server.getProcessId(hashID)
      Server.genList(temp,numNodes,x,pid)
    end)


  #initialize table
    to_find=:crypto.hash(:sha,Integer.to_string(numNodes+1))|>Base.encode16 |>String.slice(0..7)
    new_root=findRoot(temp,to_find,[],0,0)
    temp = temp++[to_find]
    list = generateList(numNodes+1)

    #Dynamic Insertion of Node

    Server.start_link([to_find,list,0])
    level = Server.findMaxPrefixMatch(new_root, to_find)
    Server.insertnode(new_root,to_find,0)
    Server.ackMulticast(new_root,to_find,level)

    #Passing Request Meesage
    if numRequest > 0 do
     Enum.each(temp, fn(x)->
      main_id = Server.getProcessId(x)
      Enum.each(1..numRequest, fn(_req)->
        rand_node = Enum.random(temp)
        if rand_node != x do
          Task.async(fn-> Server.search(x,rand_node,0,main_id) end)
        end
      end)
    end)
  end
    result=Server.getMaxHop()
    IO.puts(result)
    System.halt(1)

    loop()
  end

  def loop() do
    loop()
  end

  #to generate initial routing table for any node
  def generateList(x) do
    codeString=:crypto.hash(:sha,Integer.to_string(x))|>Base.encode16 |>String.slice(0..7) # BDF23E
    stringArray = String.codepoints(codeString)
  _list = Enum.reduce(0..7,[],fn(rowNo,temp)  ->
          tempList =List.duplicate(nil,16)
          {t,_}=Integer.parse(Enum.at(stringArray,rowNo),16)
          tempList = List.replace_at(tempList,t,codeString)
          _temp = temp++[tempList]
  end)
 end


 #it returns the closest root node from the network for a given node
 def findRoot(network_list,new_node,neigh_list,pos,added_weight) do
 char_node = String.at(new_node,pos)
 {t,_} = Integer.parse(char_node, 16)
  char_node=Integer.to_string(rem(t+added_weight,16),16)
  updated_neigh=Enum.reduce(network_list,[],fn(element,temp)->
    char_root = String.at(element,pos)
    if(char_node==char_root) do
       _temp=temp++[element]
    else
      _temp = temp++[]
      end
  end)
  if updated_neigh==[] do
    findRoot(network_list,new_node,neigh_list,pos,added_weight+1)
  else
    if length(updated_neigh)==1 do
     Enum.at(updated_neigh,0)
    else
      if(pos<String.length(new_node)-1) do
        findRoot(updated_neigh,new_node,neigh_list,pos+1,0)
      end
  end
  end
 end

end
Tapestry.start

