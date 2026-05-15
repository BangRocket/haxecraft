package shared.proto;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ComplexTypeTools;

class SerializableMacro {
  public static function build():Array<Field> {
    var fields = Context.getBuildFields();
    var pos = Context.currentPos();

    var writeExprs:Array<Expr> = [];
    var readExprs:Array<Expr> = [];

    for (f in fields) {
      switch f.kind {
        case FVar(t, _):
          if (t == null) continue;
          var fname = f.name;
          var typeStr = ComplexTypeTools.toString(t);
          switch typeStr {
            case "Int":
              writeExprs.push(macro out.writeInt32(this.$fname));
              readExprs.push(macro inst.$fname = inp.readInt32());
            case "String":
              writeExprs.push(macro {
                var __bytes = haxe.io.Bytes.ofString(this.$fname);
                out.writeUInt16(__bytes.length);
                if (__bytes.length > 0) out.writeBytes(__bytes, 0, __bytes.length);
              });
              readExprs.push(macro {
                var __len = inp.readUInt16();
                inst.$fname = __len > 0 ? inp.read(__len).toString() : "";
              });
            case "Bool":
              writeExprs.push(macro out.writeByte(this.$fname ? 1 : 0));
              readExprs.push(macro inst.$fname = inp.readByte() != 0);
            case "UInt":
              // Wire format: u8. Any field declared UInt is treated as u8 protocol field.
              writeExprs.push(macro out.writeByte(this.$fname & 0xff));
              readExprs.push(macro inst.$fname = inp.readByte());
            default:
              Context.error("SerializableMacro: unsupported type '" + typeStr +
                "' on field '" + fname + "' (supported: Int, String, Bool, UInt)", f.pos);
          }
        default:
          // skip non-var fields (methods, properties)
      }
    }

    var localCls = Context.getLocalClass().get();
    var clsPath = (localCls.pack.length > 0 ? localCls.pack.join(".") + "." : "") + localCls.name;
    var clsTypePath:TypePath = { pack: localCls.pack, name: localCls.name };
    var clsComplexType:ComplexType = TPath(clsTypePath);

    fields.push({
      name: "serialize",
      pos: pos,
      access: [APublic],
      kind: FFun({
        args: [{ name: "out", type: macro:haxe.io.BytesOutput }],
        ret: macro:Void,
        expr: macro $b{writeExprs}
      })
    });

    fields.push({
      name: "deserialize",
      pos: pos,
      access: [APublic, AStatic],
      kind: FFun({
        args: [{ name: "inp", type: macro:haxe.io.Input }],
        ret: clsComplexType,
        expr: macro {
          var inst = new $clsTypePath();
          $b{readExprs};
          return inst;
        }
      })
    });

    return fields;
  }
}
#end
