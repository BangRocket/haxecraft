package entity;

import item.Item;
import item.ResourceItem;
import item.resource.Resource;

class Inventory {
	public var items:Array<Item> = [];

	public function new() {}

	public function add(item:Item) {
		addSlot(items.length, item);
	}

	public function addSlot(slot:Int, item:Item) {
		if (Std.isOfType(item, ResourceItem)) {
			var toTake = cast(item, ResourceItem);
			var has = findResource(toTake.resource);
			if (has == null) {
				items.insert(slot, toTake);
			} else {
				has.count += toTake.count;
			}
		} else {
			items.insert(slot, item);
		}
	}

	function findResource(resource:Resource):ResourceItem {
		for (i in 0...items.length) {
			if (Std.isOfType(items[i], ResourceItem)) {
				var has = cast(items[i], ResourceItem);
				if (has.resource == resource) return has;
			}
		}
		return null;
	}

	public function hasResources(r:Resource, count:Int):Bool {
		var ri = findResource(r);
		if (ri == null) return false;
		return ri.count >= count;
	}

	public function removeResource(r:Resource, count:Int):Bool {
		var ri = findResource(r);
		if (ri == null) return false;
		if (ri.count < count) return false;
		ri.count -= count;
		if (ri.count <= 0) items.remove(ri);
		return true;
	}

	public function count(item:Item):Int {
		if (Std.isOfType(item, ResourceItem)) {
			var ri = findResource(cast(item, ResourceItem).resource);
			if (ri != null) return ri.count;
		} else {
			var count = 0;
			for (i in 0...items.length) {
				if (items[i].matches(item)) count++;
			}
			return count;
		}
		return 0;
	}
}
