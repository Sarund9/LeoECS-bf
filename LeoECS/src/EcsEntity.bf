// ----------------------------------------------------------------------------
// The MIT License
// Simple Entity Component System framework https://github.com/Leopotam/ecs
// Copyright (c) 2017-2021 Leopotam <leopotam@gmail.com>
// ----------------------------------------------------------------------------

using System;

using internal Leopotam.Ecs;

namespace Leopotam.Ecs
{
    /// <summary>
    /// Entity descriptor.
    /// </summary>
    public struct EcsEntity : IEquatable<EcsEntity>, IHashable
	{
        internal int Id;
        internal uint16 Gen;
        internal EcsWorld Owner;
#if !ECS_DISABLE_DEBUG_CHECKS
        // For using in IDE debugger.
        internal Object[] Components {
            get {
                Object[] list = null;
                if (this.IsAlive ()) {
                    this.GetComponentValues (ref list);
                }
                return list;
            }
        }
#endif

        public static readonly EcsEntity Null = EcsEntity ();

        [Inline]
        public static bool operator == (in EcsEntity lhs, in EcsEntity rhs)
		{
            return lhs.Id == rhs.Id && lhs.Gen == rhs.Gen;
        }

        [Inline]
        public static bool operator != (in EcsEntity lhs, in EcsEntity rhs)
		{
            return lhs.Id != rhs.Id || lhs.Gen != rhs.Gen;
        }

        [Inline]
        public int GetHashCode ()
		{
			// TODO: Does this require Refactoring ?
            unchecked {
                // ReSharper disable NonReadonlyMemberInGetHashCode
                var hashCode = (Id * 397) ^ Gen.GetHashCode ();
                hashCode = (hashCode * 397) ^ (Owner != null ? Owner.GetHashCode () : 0);
                // ReSharper restore NonReadonlyMemberInGetHashCode
                return hashCode;
            }
        }

        /*[Inline]
        public bool Equals (Object other)
		{
			// Method is Unnesesary (Look below)
			/*return other is EcsEntity otherEntity && Equals (otherEntity);*/
            return other is EcsEntity otherEntity && Equals (otherEntity);
        }*/

#if !ECS_DISABLE_DEBUG_CHECKS
        /*public override string ToString ()
		{
            if (this.IsNull ()) { return "Entity-Null"; }
            if (!this.IsAlive ()) { return "Entity-NonAlive"; }
            Type[] types = null;
            this.GetComponentTypes (ref types);
            var sb = new System.Text.StringBuilder (512);
            for (var type in types)
			{
                if (sb.Length > 0) { sb.Append (","); }
                sb.Append (scope $"{type}");
            }
            return scope $"Entity-{Id}:{Gen} [{sb}]";
        }*/

		public override void ToString(System.String strBuffer)
		{
			if (this.IsNull ())
			{
				strBuffer.Append("Entity-Null");
				return;
			}
			if (!this.IsAlive ())
			{
				strBuffer.Append("Entity-NonAlive");
				return ;
			}
			Type[] types = null;
			this.GetComponentTypes (ref types);
			for (var type in types)
			{
			    if (strBuffer.Length > 0) { strBuffer.Append (","); }
			    strBuffer.Append (scope $"{type}");
			}
		}
#endif

        public bool Equals (EcsEntity other)
		{
            return Id == other.Id && Gen == other.Gen && Owner == other.Owner;
        }
    }


    public extension EcsEntity
	{
        /// <summary>
        /// Replaces or adds new one component to entity.
        /// </summary>
        /// <typeparam name="T">Type of component.</typeparam>
        /// <param name="entity">Entity.</param>
        /// <param name="item">New value of component.</param>

        [Inline]
        public EcsEntity Replace<T> (in T item) where T : struct
		{
            ref EcsWorld.EcsEntityData entityData = ref Owner.GetEntityData (this);
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (entityData.Gen != entity.Gen) { throw new Exception ("Cant add component to destroyed entity."); }*/
			Runtime.Assert(entityData.Gen == Gen, "Cant add component to destroyed entity.");
#endif
            var typeIdx = EcsComponentType<T>.TypeIndex;
            // check already attached components.
            for (int i = 0, int iiMax = entityData.ComponentsCountX2; i < iiMax; i += 2)
			{
                if (entityData.Components[i] == typeIdx) {
                    ((EcsComponentPool<T>) Owner.ComponentPools[typeIdx]).Items[entityData.Components[i + 1]] = item;
                    return this;
                }
            }
            // attach new component.
            if (entityData.Components.Count == entityData.ComponentsCountX2)
			{
                Util.ResizeArray (ref entityData.Components, entityData.ComponentsCountX2 << 1);
            }
            entityData.Components[entityData.ComponentsCountX2++] = typeIdx;

            var pool = Owner.GetPool<T> ();

            var idx = pool.New ();
            entityData.Components[entityData.ComponentsCountX2++] = idx;
            pool.Items[idx] = item;
#if !ECS_DISABLE_DEBUG_CHECKS
            for (var ii = 0; ii < Owner.DebugListeners.Count; ii++)
			{
                Owner.DebugListeners[ii].OnComponentListChanged (this);
            }
#endif
            Owner.UpdateFilters (typeIdx, this, entityData);
            return this;
        }

        /// <summary>
        /// Returns exist component on entity or adds new one otherwise.
        /// </summary>
        /// <typeparam name="T">Type of component.</typeparam>

        [Inline]
        public ref T Get<T> () where T : struct
		{
            ref EcsWorld.EcsEntityData entityData = ref Owner.GetEntityData (this);
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (entityData.Gen != entity.Gen) { throw new Exception ("Cant add component to destroyed entity."); }*/
			Runtime.Assert(entityData.Gen == this.Gen, "Cant add component to destroyed entity.");
#endif
            var typeIdx = EcsComponentType<T>.TypeIndex;
            // check already attached components.
            for (int i = 0, int iiMax = entityData.ComponentsCountX2; i < iiMax; i += 2)
			{
                if (entityData.Components[i] == typeIdx) {
                    return ref ((EcsComponentPool<T>) this.Owner.ComponentPools[typeIdx]).Items[entityData.Components[i + 1]];
                }
            }
            // attach new component.
            if (entityData.Components.Count == entityData.ComponentsCountX2)
			{
                Util.ResizeArray (ref entityData.Components, entityData.ComponentsCountX2 << 1);
            }
            entityData.Components[entityData.ComponentsCountX2++] = typeIdx;

            var pool = this.Owner.GetPool<T> ();

            var idx = pool.New ();
            entityData.Components[entityData.ComponentsCountX2++] = idx;
#if !ECS_DISABLE_DEBUG_CHECKS
            for (var ii = 0; ii < this.Owner.DebugListeners.Count; ii++)
			{
                this.Owner.DebugListeners[ii].OnComponentListChanged (this);
            }
#endif
            this.Owner.UpdateFilters (typeIdx, this, entityData);
            return ref pool.Items[idx];
        }

        /// <summary>
        /// Checks that component is attached to entity.
        /// </summary>
        /// <typeparam name="T">Type of component.</typeparam>

        [Inline]
        public bool Has<T> () where T : struct
		{
            ref EcsWorld.EcsEntityData entityData = ref this.Owner.GetEntityData (this);
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (entityData.Gen != entity.Gen) { throw new Exception ("Cant check component on destroyed entity."); }*/
			Runtime.Assert(entityData.Gen == this.Gen, "Cant check component on destroyed entity.");
#endif
            var typeIdx = EcsComponentType<T>.TypeIndex;
            for (int i = 0, int iMax = entityData.ComponentsCountX2; i < iMax; i += 2)
			{
                if (entityData.Components[i] == typeIdx)
				{
                    return true;
                }
            }
            return false;
        }

        /// <summary>
        /// Removes component from entity.
        /// </summary>
        /// <typeparam name="T">Type of component.</typeparam>

        [Inline]
        public void Del<T> () where T : struct
		{
            var typeIndex = EcsComponentType<T>.TypeIndex;
            ref EcsWorld.EcsEntityData entityData = ref this.Owner.GetEntityData (this);
            // save copy to local var for protect from cleanup fields outside.
            var owner = this.Owner;
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (entityData.Gen != entity.Gen) { throw new Exception ("Cant touch destroyed entity."); }*/
			Runtime.Assert(entityData.Gen == this.Gen, "Cant touch destroyed entity.");
#endif
            for (int i = 0, int iMax = entityData.ComponentsCountX2; i < iMax; i += 2)
			{
                if (entityData.Components[i] == typeIndex)
				{
                    owner.UpdateFilters (-typeIndex, this, entityData);
#if !ECS_DISABLE_DEBUG_CHECKS
                    // var removedComponent = owner.ComponentPools[typeIndex].GetItem (entityData.Components[i + 1]);
#endif
                    owner.ComponentPools[typeIndex].Recycle (entityData.Components[i + 1]);
                    // remove current item and move last component to this gap.
                    entityData.ComponentsCountX2 -= 2;
                    if (i < entityData.ComponentsCountX2)
					{
                        entityData.Components[i] = entityData.Components[entityData.ComponentsCountX2];
                        entityData.Components[i + 1] = entityData.Components[entityData.ComponentsCountX2 + 1];
                    }
#if !ECS_DISABLE_DEBUG_CHECKS
                    for (var ii = 0; ii < this.Owner.DebugListeners.Count; ii++)
					{
                        this.Owner.DebugListeners[ii].OnComponentListChanged (this);
                    }
#endif
                    break;
                }
            }
            // unrolled and inlined Destroy() call.
            if (entityData.ComponentsCountX2 == 0)
			{
                owner.RecycleEntityData (this.Id, ref entityData);
#if !ECS_DISABLE_DEBUG_CHECKS
                for (var ii = 0; ii < this.Owner.DebugListeners.Count; ii++)
				{
                    owner.DebugListeners[ii].OnEntityDestroyed (this);
                }
#endif
            }
        }

        /// <summary>
        /// Creates copy of entity with all components.
        /// </summary>

        [Inline]
        public EcsEntity Copy ()
		{
            var owner = this.Owner;
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (owner == null) { throw new Exception ("Cant copy invalid entity."); }*/
			Runtime.Assert(owner != null, "Cant copy invalid entity.");
#endif
            ref EcsWorld.EcsEntityData srcData = ref owner.GetEntityData (this);
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (srcData.Gen != entity.Gen) { throw new Exception ("Cant copy destroyed entity."); }*/
			Runtime.Assert(srcData.Gen == this.Gen, "Cant copy destroyed entity.");
#endif
            var dstEntity = owner.NewEntity ();
            ref EcsWorld.EcsEntityData dstData = ref owner.GetEntityData (dstEntity);
            if (dstData.Components.Count < srcData.ComponentsCountX2)
			{
                dstData.Components = new int[srcData.Components.Count];
            }
            dstData.ComponentsCountX2 = 0;
            for (int i = 0, int iiMax = srcData.ComponentsCountX2; i < iiMax; i += 2)
			{
                var typeIdx = srcData.Components[i];
                var pool = owner.ComponentPools[typeIdx];
                var dstItemIdx = pool.New ();
                dstData.Components[i] = typeIdx;
                dstData.Components[i + 1] = dstItemIdx;
                pool.CopyData (srcData.Components[i + 1], dstItemIdx);
                dstData.ComponentsCountX2 += 2;
                owner.UpdateFilters (typeIdx, dstEntity, dstData);
            }
#if !ECS_DISABLE_DEBUG_CHECKS
            for (var ii = 0; ii < owner.DebugListeners.Count; ii++)
			{
                owner.DebugListeners[ii].OnComponentListChanged (this);
            }
#endif
            return dstEntity;
        }

        /// <summary>
        /// Adds copies of source entity components
        /// on target entity (overwrite exists) and
        /// removes source entity.
        /// </summary>

        [Inline]
        public void MoveTo (in EcsEntity target)
		{
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (!source.IsAlive ()) { throw new Exception ("Cant move from invalid entity."); }*/
			Runtime.Assert(!this.IsAlive(), "Cant move from invalid entity.");
            /*if (!target.IsAlive ()) { throw new Exception ("Cant move to invalid entity."); }*/
			Runtime.Assert(!target.IsAlive(), "Cant move to invalid entity.");
            /*if (source.Owner != target.Owner) { throw new Exception ("Cant move data between worlds."); }*/
			Runtime.Assert(this.Owner == target.Owner, "Cant move data between worlds.");
            /*if (source.AreEquals (target)) { throw new Exception ("Source and target entities are same."); }*/
			Runtime.Assert(!this.AreEquals (target), "Source and target entities are same.");
            var componentsListChanged = false;
#endif
            var owner = this.Owner;
            ref EcsWorld.EcsEntityData srcData = ref owner.GetEntityData (this);
            ref EcsWorld.EcsEntityData dstData = ref owner.GetEntityData (target);
            if (dstData.Components.Count < srcData.ComponentsCountX2)
			{
                dstData.Components = new int[srcData.Components.Count];
            }
            for (int i = 0, int iiMax = srcData.ComponentsCountX2; i < iiMax; i += 2)
			{
                var typeIdx = srcData.Components[i];
                var pool = owner.ComponentPools[typeIdx];
                var j = dstData.ComponentsCountX2 - 2;
                // search exist component on target.
                for (; j >= 0; j -= 2)
				{
                    if (dstData.Components[j] == typeIdx) { break; }
                }
                if (j >= 0)
				{
                    // found, copy data.
                    pool.CopyData (srcData.Components[i + 1], dstData.Components[j + 1]);
                }
				else
				{
                    // add new one.
                    if (dstData.Components.Count == dstData.ComponentsCountX2)
					{
                        Util.ResizeArray (ref dstData.Components, dstData.ComponentsCountX2 << 1);
                    }
                    dstData.Components[dstData.ComponentsCountX2] = typeIdx;
                    var idx = pool.New ();
                    dstData.Components[dstData.ComponentsCountX2 + 1] = idx;
                    dstData.ComponentsCountX2 += 2;
                    pool.CopyData (srcData.Components[i + 1], idx);
                    owner.UpdateFilters (typeIdx, target, dstData);
#if !ECS_DISABLE_DEBUG_CHECKS
                    componentsListChanged = true;
#endif
                }
            }
#if !ECS_DISABLE_DEBUG_CHECKS
            if (componentsListChanged)
			{
                for (var ii = 0; ii < owner.DebugListeners.Count; ii++)
				{
                    owner.DebugListeners[ii].OnComponentListChanged (target);
                }
            }
#endif
            this.Destroy ();
        }

        /// <summary>
        /// Gets component index at component pool.
        /// If component doesn't exists "-1" will be returned.
        /// </summary>
        /// <typeparam name="T">Type of component.</typeparam>

        [Inline]
        public int GetComponentIndexInPool<T> () where T : struct
		{
            ref EcsWorld.EcsEntityData entityData = ref this.Owner.GetEntityData (this);
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (entityData.Gen != entity.Gen) { throw new Exception ("Cant check component on destroyed entity."); }*/
			Runtime.Assert(entityData.Gen == this.Gen, "Cant check component on destroyed entity.");
#endif
            var typeIdx = EcsComponentType<T>.TypeIndex;
            for (int i = 0, int iMax = entityData.ComponentsCountX2; i < iMax; i += 2) {
                if (entityData.Components[i] == typeIdx) {
                    return entityData.Components[i + 1];
                }
            }
            return -1;
        }

        /// <summary>
        /// Compares entities. 
        /// </summary>
        [Inline]
        public  bool AreEquals ( in EcsEntity rhs)
		{
            return this.Id == rhs.Id && this.Gen == rhs.Gen;
        }

        /// <summary>
        /// Compares internal Ids without Gens check. Use carefully! 
        /// </summary>
        [Inline]
        public bool AreIdEquals (in EcsEntity rhs)
		{
            return this.Id == rhs.Id;
        }

        /// <summary>
        /// Gets internal identifier.
        /// </summary>
        [Inline]
        public int GetInternalId ()
		{
            return this.Id;
        }

        /// <summary>
        /// Gets internal generation.
        /// </summary>
        public int GetInternalGen ()
		{
            return this.Gen;
        }

        /// <summary>
        /// Gets internal world.
        /// </summary>
        public EcsWorld GetInternalWorld ()
		{
            return this.Owner;
        }

        /// <summary>
        /// Gets ComponentRef wrapper to keep direct reference to component.
        /// </summary>
        /// <param name="entity">Entity.</param>
        /// <typeparam name="T">Component type.</typeparam>
        [Inline]
        public EcsComponentRef<T> Ref<T> () where T : struct
		{
            ref EcsWorld.EcsEntityData entityData = ref this.Owner.GetEntityData (this);
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (entityData.Gen != entity.Gen) { throw new Exception ("Cant wrap component on destroyed entity."); }*/
			Runtime.Assert(entityData.Gen == this.Gen, "Cant wrap component on destroyed entity.");
#endif
            var typeIdx = EcsComponentType<T>.TypeIndex;
            for (int i = 0, int iMax = entityData.ComponentsCountX2; i < iMax; i += 2)
			{
                if (entityData.Components[i] == typeIdx)
				{
                    return ((EcsComponentPool<T>) this.Owner.ComponentPools[entityData.Components[i]]).Ref (entityData.Components[i + 1]);
                }
            }
#if !ECS_DISABLE_DEBUG_CHECKS
            /*throw new Exception ($"\"{typeof (T).Name}\" component not exists on entity for wrapping.");*/
			Runtime.Assert(false, scope $"\"{typeof(T)}\" component not exists on entity for wrapping.");
#endif
            return default;
        }

        /// <summary>
        /// Removes components from entity and destroys it.
        /// </summary>

        [Inline]
        public void Destroy ()
		{
            ref EcsWorld.EcsEntityData entityData = ref this.Owner.GetEntityData (this);
            // save copy to local var for protect from cleanup fields outside.
            EcsEntity savedEntity;
            savedEntity.Id = this.Id;
            savedEntity.Gen = this.Gen;
            savedEntity.Owner = this.Owner;
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (entityData.Gen != entity.Gen) { throw new Exception ("Cant touch destroyed entity."); }*/
			Runtime.Assert(entityData.Gen == this.Gen, "Cant touch destroyed entity.");
#endif
            // remove components first.
            for (var i = entityData.ComponentsCountX2 - 2; i >= 0; i -= 2)
			{
                savedEntity.Owner.UpdateFilters (-entityData.Components[i], savedEntity, entityData);
                savedEntity.Owner.ComponentPools[entityData.Components[i]].Recycle (entityData.Components[i + 1]);
                entityData.ComponentsCountX2 -= 2;
#if !ECS_DISABLE_DEBUG_CHECKS
                for (var ii = 0; ii < savedEntity.Owner.DebugListeners.Count; ii++)
				{
                    savedEntity.Owner.DebugListeners[ii].OnComponentListChanged (savedEntity);
                }
#endif
            }
            entityData.ComponentsCountX2 = 0;
            savedEntity.Owner.RecycleEntityData (savedEntity.Id, ref entityData);
#if !ECS_DISABLE_DEBUG_CHECKS
            for (var ii = 0; ii < savedEntity.Owner.DebugListeners.Count; ii++)
			{
                savedEntity.Owner.DebugListeners[ii].OnEntityDestroyed (savedEntity);
            }
#endif
        }

        /// <summary>
        /// Is entity null-ed.
        /// </summary>
        [Inline]
        public bool IsNull ()
		{
            return this.Id == 0 && this.Gen == 0;
        }

        /// <summary>
        /// Is entity alive. If world was destroyed - false will be returned.
        /// </summary>

        [Inline]
        public bool IsAlive ()
		{
            if (!IsWorldAlive ()) { return false; }
            ref EcsWorld.EcsEntityData entityData = ref this.Owner.GetEntityData (this);
            return entityData.Gen == this.Gen && entityData.ComponentsCountX2 >= 0;
        }

        /// <summary>
        /// Is world alive.
        /// </summary>

        [Inline]
        public bool IsWorldAlive ()
		{
            return this.Owner != null && this.Owner.IsAlive ();
        }

        /// <summary>
        /// Gets components count on entity.
        /// </summary>

        [Inline]
        public int GetComponentsCount ()
		{
            ref EcsWorld.EcsEntityData entityData = ref this.Owner.GetEntityData (this);
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (entityData.Gen != entity.Gen) { throw new Exception ("Cant touch destroyed entity."); }*/
			Runtime.Assert(entityData.Gen == this.Gen, "Cant touch destroyed entity.");
#endif
            return entityData.ComponentsCountX2 <= 0 ? 0 : (entityData.ComponentsCountX2 >> 1);
        }

        /// <summary>
        /// Gets types of all attached components.
        /// </summary>
        /// <param name="entity">Entity.</param>
        /// <param name="list">List to put results in it. if null - will be created. If not enough space - will be resized.</param>
        /// <returns>Amount of components in list.</returns>
        public int GetComponentTypes (ref Type[] list)
		{
            ref EcsWorld.EcsEntityData entityData = ref this.Owner.GetEntityData (this);
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (entityData.Gen != entity.Gen) { throw new Exception ("Cant touch destroyed entity."); }*/
			Runtime.Assert(entityData.Gen == this.Gen, "Cant touch destroyed entity.");
#endif
            var itemsCount = entityData.ComponentsCountX2 >> 1;
            if (list == null || list.Count < itemsCount)
			{
                list = new Type[itemsCount];
            }
            for (int i = 0, int j = 0, int iMax = entityData.ComponentsCountX2; i < iMax; i += 2, j++)
			{
                list[j] = this.Owner.ComponentPools[entityData.Components[i]].ItemType;
            }
            return itemsCount;
        }

        /// <summary>
        /// Gets values of all attached components as copies. Important: force boxing / unboxing!
        /// </summary>
        /// <param name="entity">Entity.</param>
        /// <param name="list">List to put results in it. if null - will be created. If not enough space - will be resized.</param>
        /// <returns>Amount of components in list.</returns>
        public int GetComponentValues ( ref Object[] list)
		{
            ref EcsWorld.EcsEntityData entityData = ref this.Owner.GetEntityData (this);
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (entityData.Gen != entity.Gen) { throw new Exception ("Cant touch destroyed entity."); }*/
			Runtime.Assert(entityData.Gen == this.Gen, "Cant touch destroyed entity.");
#endif
            var itemsCount = entityData.ComponentsCountX2 >> 1;
            if (list == null || list.Count < itemsCount) {
                list = new Object[itemsCount];
            }
            for (int i = 0, int j = 0, int iMax = entityData.ComponentsCountX2; i < iMax; i += 2, j++) {
                list[j] = this.Owner.ComponentPools[entityData.Components[i]].GetItem (entityData.Components[i + 1]);
            }
            return itemsCount;
        }
    }
}