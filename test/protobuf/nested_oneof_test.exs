defmodule Protobuf.NestedOneof.Test do
  use Protobuf.Case

  defmodule Msgs do
    use Protobuf, from: Path.expand("../proto/nested_oneof.proto", __DIR__)
  end

  test "can encode nested oneof proto" do
    bar = Msgs.Bar.new msg: "msg"
    c = Msgs.Container.new hello: "hello", msg: {:bar, bar}
    enc_c = c |> Msgs.Container.encode

    assert is_binary(enc_c)
  end

  test "can encode deeply nested oneof proto" do
    sfm = Msgs.SingleFooMetadata.new baz_id: "baz_id"
    fm = Msgs.FooMetadata.new type: {:single_metadata, sfm}
    foo = Msgs.Foo.new foo_id: "foo_id", created_at: 0, metadata: fm
    c = Msgs.Container.new msg: {:foo, foo}
    enc_c = c |> Msgs.Container.encode

    assert is_binary(enc_c)
  end

end
