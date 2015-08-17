defmodule Protobuf.Oneof.Test do
  use Protobuf.Case

  defmodule OneofMsg do
    use Protobuf, from: Path.expand("../proto/oneof.proto", __DIR__)
  end
  
  test "can create oneof protos" do
    msg = OneofMsg.SampleOneofMsg.new(one: "test", foo: {:body, "xxx"})
    assert %{one: "test", foo: {:body, "xxx"}} = msg  
  end
  
  test "can encode simple oneof protos" do
    msg = OneofMsg.SampleOneofMsg.new(one: "test", foo: {:body, "xxx"})

    encoded = OneofMsg.SampleOneofMsg.encode(msg)
    binary = <<10, 4, 116, 101, 115, 116, 26, 3, 120, 120, 120>>
    
    assert binary == encoded
  end
  
  test "can decode simple oneof protos" do
    binary = <<10, 4, 116, 101, 115, 116, 26, 3, 120, 120, 120>>

    msg = OneofMsg.SampleOneofMsg.decode(binary)
    assert %OneofMsg.SampleOneofMsg{foo: {:body, 'xxx'}, one: "test"} == msg  
    
  end
end
