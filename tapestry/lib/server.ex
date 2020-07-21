defmodule Server do
  use GenServer
  def start_link(state) do
    {:ok,pid} = GenServer.start_link(__MODULE__,state) # [hashID,]
    hashID = Enum.at(state,0)
    #IO.inspect(pid)
   # IO.inspect(Enum.at(state, 1))
    :ets.insert(:processTable,{hashID,pid})
  end

  def init(state) do
    Process.flag(:trap_exit,true)
    {:ok,state}
  end


def genList(temp,numNodes,x,pid) do
  GenServer.cast(pid, {:genList,temp,numNodes,x})
end

  #below are the get and set functions
  def get_state(pid) do
    state=GenServer.call(pid,:get_state,:infinity)
    state
  end

  def getMaxHop() do
    [{_,count}] = :ets.lookup(:hopCount,"maxHop")
    count
  end

  def updateHop(newHop) do
    :ets.insert(:hopCount,{"maxHop",newHop})
  end
  def handle_call(:get_state,_from,state) do
    {:reply,state,state}
  end

  def getProcessId(hashID) do
    [{_,pid}] = :ets.lookup(:processTable,hashID)
    pid
  end

  def getListAt(pid,level) do
    state = get_state(pid)
    levelList = Enum.at(Enum.at(state,1),level)
    levelList
  end


def updateRootTable(node_value,level,col,pid) do
  GenServer.cast(pid,{:update_node,node_value,level,col})
end

  def handle_cast({:updateList,list},state) do
    [id,_list,hop] = state
    {:noreply,[id,list,hop]}
  end

#generate routing table
def handle_cast({:genList,t,_numNodes,i},state) do
  codeString=:crypto.hash(:sha,Integer.to_string(i))|>Base.encode16 |>String.slice(0..7)
  hashID=Enum.filter(t,fn x-> x != codeString end)

  list = Enum.reduce(0..7,[],fn row,temp ->
    difList=Enum.filter(hashID,fn x-> String.slice(codeString,0,row)==String.slice(x,0,row) and String.slice(codeString,0,row+1)!=String.slice(x,0,row+1) end)
    final=Enum.reduce(0..15,[],fn col,some ->
          coList=Enum.filter(difList,fn dif-> String.slice(dif,row,1) == Integer.to_string(col, 16) end)
          if length(coList)<=1 do
            put_list=List.first(coList)
            some++[put_list]
          else
            put_list=Tapestry.findRoot(coList,codeString,[],0,0)
            some++[put_list]
          end
    end)

    stringArray = String.codepoints(codeString)
    {t,_}=Integer.parse(Enum.at(stringArray,row),16)
    final = List.replace_at(final,t,codeString)

    _temp= temp ++ [final]
  end)
  {:noreply,[codeString,list,Enum.at(state,2)]}
end

# to update single value at a position


def handle_cast({:update_node,node_value,level,col},state) do
  node_list = Enum.at(state,1)
  new_list=List.replace_at(Enum.at(node_list,level),col,node_value)
  new_temp =List.replace_at(node_list,level,new_list)
  {:noreply,[Enum.at(state,0),new_temp,Enum.at(state,2)]}
end
#------------------------------------

  #to insert a single node with a given root
  def insertnode(root,insert_node,ackFlag) do
   root_id = getProcessId(root)
   level = findMaxPrefixMatch(root, insert_node)
    root_list = getListAt(root_id,level)
    stringArray = String.codepoints(insert_node)
    char_val = Enum.at(stringArray,level)
   {char_pos,_} = Integer.parse(char_val,16)
   field = Enum.at(root_list,char_pos)

   if(ackFlag==0) do
    updateNewNodeTable(insert_node,root,level)
   end

   if(field==nil) do
     updateRootTable(insert_node,level,char_pos,root_id)
   else
    min_list = [field,insert_node]
    node = Tapestry.findRoot(min_list,root,[],0,0)
    if node == insert_node  do
      updateRootTable(insert_node,level,char_pos,root_id)
    end
   end
  end

# Search

def search(root,node,hops,main_id) do
  level = findMaxPrefixMatch(root, node) #row
  root_id = getProcessId(root)
  root_list = getListAt(root_id,level)
  field=Tapestry.findRoot(root_list,node,[],0,0)
  if field == node do
    maxHop = getMaxHop()
    if(hops>maxHop) do
      updateHop(hops)
    end
  else
    search(field,node,hops+1,main_id)
  end

end


   #Ack Multicast
   def ackMulticast(root,insert_node,level) do
    last = String.length(root)
    root_id = getProcessId(root)
    if level<last do
    Enum.each(level..last-1, fn(x)  ->
      temp_list = getListAt(root_id,x)
      Enum.each(temp_list, fn (ackElement) ->
          if ackElement != insert_node and (ackElement != root and ackElement != nil) do
            insertnode(ackElement,insert_node,1)
            ackMulticast(ackElement,insert_node,level+1)
          end
        end)
    end)
  end

  end

   #test_function to check table

  def test_node(hashID) do
    pid = getProcessId(hashID)
    state=get_state(pid)
    IO.inspect(Enum.at(state,1))
  end

  #here below we copy from root to node level


def updateNewNodeTable(new_node,root_node_id,uptoLevel) do
  pid = getProcessId(new_node)
  root_id = getProcessId(root_node_id)
  state = get_state(root_id)
  root_list = Enum.at(state,1)
  _state=get_state(pid)


  Enum.each(0..uptoLevel,fn(x)->
    state=get_state(pid)
    node_list = Enum.at(state,1)
    temp_list = Enum.at(root_list,x)
    new_list=List.replace_at(node_list,x,temp_list)
    #IO.inspect(new_list)
    GenServer.cast(pid,{:updateList,new_list})
  end)
end

  #---------------------------------------------------



#to find which one has minimum distance
  def findNodeWithMinDist(new_field,curr_field) do
    a = Integer.parse(new_field,16)
    b = Integer.parse(curr_field,16)
    if a<b do
      new_field
    else
      curr_field
    end
  end

#to find to what extend are two nodes sharing common prefix
  def findMaxPrefixMatch(a,b) do
    a=Enum.reduce_while(0..7,0,fn i,acc->
      x = String.slice(a,i,1)
      y = String.slice(b,i,1)
        if x==y, do: {:cont, acc + 1},else: {:halt, acc}
       end)
    a
  end


end
