defmodule Protobuf.Oneof.Test do
  use Protobuf.Case

  defmodule Msgs do
    use Protobuf, from: Path.expand("../proto/oneof.proto", __DIR__)
  end
    
  test "can create oneof protos" do
    msg = Msgs.SampleOneofMsg.new(one: "test", foo: {:body, "xxx"})
    assert %{one: "test", foo: {:body, "xxx"}} = msg  
  end
  
  test "can encode simple oneof protos" do
    msg = Msgs.SampleOneofMsg.new(one: "test", foo: {:body, "xxx"})

    encoded = Msgs.SampleOneofMsg.encode(msg)
    binary = <<10, 4, 116, 101, 115, 116, 26, 3, 120, 120, 120>>
    
    assert binary == encoded
  end
  
  test "can decode simple oneof protos" do
    binary = <<10, 4, 116, 101, 115, 116, 26, 3, 120, 120, 120>>

    msg = Msgs.SampleOneofMsg.decode(binary)
    assert %Msgs.SampleOneofMsg{foo: {:body, 'xxx'}, one: "test"} == msg
  end
  
  test "stucture parsed simple oneof proto properly" do
    defs = Msgs.SampleOneofMsg.defs(:field, :foo)
    
    assert %Protobuf.OneofField{fields: [%Protobuf.Field{fnum: 3, name: :body, occurrence: :optional, opts: [], rnum: 3, type: :string},
              %Protobuf.Field{fnum: 4, name: :code, occurrence: :optional, opts: [], rnum: 3, type: :uint32}], name: :foo, rnum: 3} = defs
    
  end
  
  test "can create oneof protos with sub messages" do
    msg = Msgs.AdvancedOneofMsg.new(one: Msgs.SubMsg.new(test: "xxx"), 
                                          foo: {:body, Msgs.SubMsg.new(test: "yyy")})
    
    assert %{one: %{test: "xxx"}, foo: {:body, %{test: "yyy"}}} = msg
  end
  
  test "can encode oneof protos with sub messages" do
    msg = Msgs.AdvancedOneofMsg.new(one: Msgs.SubMsg.new(test: "xxx"), foo: {:body, Msgs.SubMsg.new(test: "yyy")})


    encoded = Msgs.AdvancedOneofMsg.encode(msg)
    
    binary = <<10, 5, 10, 3, 120, 120, 120, 26, 5, 10, 3, 121, 121, 121>>
    
    assert binary == encoded
  end
  
  test "can decode oneof protos with sub messages" do
    binary = <<10, 5, 10, 3, 120, 120, 120, 26, 5, 10, 3, 121, 121, 121>>
    
    msg = Msgs.SampleOneofMsg.decode(binary)
    assert %Msgs.SampleOneofMsg{foo: {:body,  Msgs.SubMsg.new(test: "yyy")}, one: Msgs.SubMsg.new(test: "xxx")} == msg
  end
  
end
