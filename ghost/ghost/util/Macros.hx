package ghost.util;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using haxe.macro.Tools;

class Macros {
  static function type_exists(typeName:String):Bool {
    try {
      if (Context.getType(typeName) != null) return true;
    } catch (error:String) {}

    return false;
  }

  static function is_subclass(is:ClassType, of:ClassType):Bool {
    if (is.superClass == null) return false;
    return is.superClass.t.get().name == of.name;
  }

  static function build_system():Array<Field> {
    var fields = Context.getBuildFields();
    var addNodesExpr:Array<Expr> = [];
    var removeNodesExpr:Array<Expr> = [];

    // Loop through each field
    for (field in fields) {
      // Look for fields with the @:nodes metadata
      if (field.meta != null) for (tag in field.meta) if (tag.name == ':nodes') {
        // Ensure the field is a Variable
        switch field.kind {
          case FVar(t, e):
            var fieldName = field.name;
            // Set the field type to `Nodes`
            field.kind = FieldType.FVar(macro:ghost.util.Nodes<$t>, e);
            // Get the TypePath of the `Node` class
            var ct = t.toType().getClass();
            var typePath = {
              name: ct.name,
              pack: ct.pack
            }
            var fullNodeName = '${ct.pack.join('.')}.${ct.name}'.split('.');
            // Make the expression to create the `Nodes` when the system is added
            addNodesExpr.push(macro $i{fieldName} = new ghost.util.Nodes(game, components -> new $typePath(components),
              (components) -> return components.has_all($p{fullNodeName}.component_types)));
            // Make the expressions to destroy the `Nodes` when the system is removed
            removeNodesExpr.push(macro {
              $i{fieldName}.dispose();
              $i{fieldName} = null;
            });
          default:
            throw('@:nodes metadata can only be used on a variable of `Node<T>` class');
        }
      }
    }

    var pos = Context.currentPos();

    // add expressions to create nodelists
    if (addNodesExpr.length > 0) fields.push({
      access: [AOverride, AInline],
      name: 'add_nodes',
      pos: pos,
      kind: FFun({
        args: [],
        ret: macro:Void,
        expr: macro $b{addNodesExpr}
      })
    });

    // add expressions to remove nodelists
    if (removeNodesExpr.length > 0) fields.push({
      access: [AOverride, AInline],
      name: 'remove_nodes',
      pos: pos,
      kind: FFun({
        args: [],
        ret: macro:Void,
        expr: macro $b{removeNodesExpr}
      })
    });

    return fields;
  }

  static function build_node():ComplexType {
    return switch (Context.getLocalType()) {
      case TInst(_.get() => {name: "Node"}, params):
        build_node_class(params);
      default:
        throw false;
    }
  }
  /**
   * Signal implementation from: https://gist.github.com/nadako/b086569b9fffb759a1b5
  **/
  static function build_signal():ComplexType {
    return switch (Context.getLocalType()) {
      case TInst(_.get() => {name: "Signal"}, params):
        build_signal_class(params);
      default:
        throw false;
    }
  }

  static function build_node_class(params:Array<Type>):ComplexType {
    var paramNames = [for (param in params) param.getClass().name.split('.').pop()].join("");
    var name = 'Node$paramNames';
    if (!type_exists('ghost.nodes.$name')) {
      var pos = Context.currentPos();
      var fields:Array<Field> = [];
      var constructorExprs:Array<Expr> = [];
      var regex = ~/(?<!^)([A-Z])/g;
      var componentClass = Context.getType('ghost.Component').getClass();
      var componentTypes:Array<Expr> = [];

      // Add an Expr to get the 'entity' to the constructor
      constructorExprs.push(macro {
        entity = components.entity;
        name = $v{name};
      });

      // Loop through the params and add them to the Node's fields
      for (param in params) {
        // Check if param is a component. throw an exception if not
        var paramClass = param.getClass();
        if (!is_subclass(paramClass, componentClass)) throw('Class `${paramClass.name}` does not extend `ghost.Component`.');

        // Make the param name snake_case
        var paramName = '';
        var testName = paramClass.name;
        while (regex.match(testName)) {
          paramName += regex.matchedLeft() + '_' + regex.matched(1);
          testName = regex.matchedRight();
        }
        paramName += testName;
        paramName = paramName.toLowerCase();

        // Add the component to the Node's fields
        fields.push({
          name: paramName,
          pos: pos,
          kind: FVar(param.toComplexType()),
          access: [APublic]
        });

        var fullComponentPath = '${paramClass.pack.join('.')}.${paramClass.name}'.split('.');

        // Add an expression to get the component in the Node's constructor
        constructorExprs.push(macro this.$paramName = components.get($p{fullComponentPath}));
        // Add an expression for the `component_types` variable
        componentTypes.push(macro $p{fullComponentPath});
      }

      // Create a static field to contain Component references
      fields.push({
        name: 'component_types',
        access: [AStatic, APublic],
        pos: pos,
        kind: FVar(macro:Array<ghost.util.ComponentType>, macro $a{componentTypes})
      });

      // Create the Constructor
      fields.push({
        name: "new",
        access: [APublic],
        pos: pos,
        kind: FFun({
          args: [{name: 'components', type: TPath({name: 'Components', pack: ['ghost', 'util']})}],
          expr: macro $b{constructorExprs},
          ret: macro:Void
        })
      });

      Context.defineType({
        pack: ['ghost', 'nodes'],
        name: name,
        pos: pos,
        params: [],
        kind: TDClass({
          pack: ['ghost'],
          name: "Node",
          sub: "NodeBase",
        }),
        fields: fields
      });
    }
    return TPath({pack: ['ghost', 'nodes'], name: name, params: []});
  }

  static function build_signal_class(params:Array<Type>):ComplexType {
    var numParams = params.length;
    var name = 'Signal$numParams';

    if (!type_exists('ghost.signals.$name')) {
      var typeParams:Array<TypeParamDecl> = [];
      var superClassFunctionArgs:Array<ComplexType> = [];
      var dispatchArgs:Array<FunctionArg> = [];
      var listenerCallParams:Array<Expr> = [];
      for (i in 0...numParams) {
        typeParams.push({name: 'T$i'});
        superClassFunctionArgs.push(TPath({name: 'T$i', pack: []}));
        dispatchArgs.push({name: 'arg$i', type: TPath({name: 'T$i', pack: []})});
        listenerCallParams.push(macro $i{'arg$i'});
      }

      var pos = Context.currentPos();

      Context.defineType({
        pack: ['ghost', 'signals'],
        name: name,
        pos: pos,
        params: typeParams,
        kind: TDClass({
          pack: ['ghost', 'util'],
          name: "Signal",
          sub: "SignalBase",
          params: [TPType(TFunction(superClassFunctionArgs, macro:Void))]
        }),
        fields: [
          {
            name: "dispatch",
            access: [APublic],
            pos: pos,
            kind: FFun({
              args: dispatchArgs,
              ret: macro:Void,
              expr: macro {
                start_dispatch();
                var conn = head;
                while (conn != null) {
                  conn.listener($a{listenerCallParams});
                  if (conn.once) conn.dispose();
                  conn = conn.next;
                }
                end_dispatch();
              }
            })
          }
        ]
      });
    }

    return TPath({pack: ['ghost', 'signals'], name: name, params: [for (t in params) TPType(t.toComplexType())]});
  }
}
#end
