// ----------------------------------------------------------------------------
// The MIT License
// Simple Entity Component System framework https://github.com/Leopotam/ecs
// Copyright (c) 2017-2021 Leopotam <leopotam@gmail.com>
// ----------------------------------------------------------------------------

using System;
using System.Collections;
using System.Globalization;
using System.Reflection;

using internal Leopotam.Ecs;

namespace Leopotam.Ecs {
    /// <summary>
    /// Ecs data context.
    /// </summary>

    // ReSharper disable once ClassWithVirtualMembersNeverInherited.Global
    public class EcsWorld : IHashable
	{
        protected EcsEntityData[] Entities;
        protected int EntitiesCount;
        protected readonly EcsGrowList<int> FreeEntities;
        protected readonly EcsGrowList<EcsFilter> Filters;
        protected readonly Dictionary<int, EcsGrowList<EcsFilter>> FilterByIncludedComponents;
        protected readonly Dictionary<int, EcsGrowList<EcsFilter>> FilterByExcludedComponents;

        // just for world stats.
        int _usedComponentsCount;

        internal readonly EcsWorldConfig Config;
        readonly Object[] _filterCtor;

        /// <summary>
        /// Creates new ecs-world instance.
        /// </summary>
        /// <param name="config">Optional config for default cache sizes. On zero or negative value - default value will be used.</param>
        public this (EcsWorldConfig config = default)
		{
            let finalConfig = EcsWorldConfig
			{
                EntityComponentsCacheSize = config.EntityComponentsCacheSize <= 0
                    ? EcsWorldConfig.DefaultEntityComponentsCacheSize
                    : config.EntityComponentsCacheSize,
                FilterEntitiesCacheSize = config.FilterEntitiesCacheSize <= 0
                    ? EcsWorldConfig.DefaultFilterEntitiesCacheSize
                    : config.FilterEntitiesCacheSize,
                WorldEntitiesCacheSize = config.WorldEntitiesCacheSize <= 0
                    ? EcsWorldConfig.DefaultWorldEntitiesCacheSize
                    : config.WorldEntitiesCacheSize,
                WorldFiltersCacheSize = config.WorldFiltersCacheSize <= 0
                    ? EcsWorldConfig.DefaultWorldFiltersCacheSize
                    : config.WorldFiltersCacheSize,
                WorldComponentPoolsCacheSize = config.WorldComponentPoolsCacheSize <= 0
                    ? EcsWorldConfig.DefaultWorldComponentPoolsCacheSize
                    : config.WorldComponentPoolsCacheSize
            };
            Config = finalConfig;
            Entities = new EcsEntityData[Config.WorldEntitiesCacheSize];
            FreeEntities = new EcsGrowList<int> (Config.WorldEntitiesCacheSize);
            Filters = new EcsGrowList<EcsFilter> (Config.WorldFiltersCacheSize);
            FilterByIncludedComponents = new Dictionary<int, EcsGrowList<EcsFilter>> (Config.WorldFiltersCacheSize);
            FilterByExcludedComponents = new Dictionary<int, EcsGrowList<EcsFilter>> (Config.WorldFiltersCacheSize);
            ComponentPools = new IEcsComponentPool[Config.WorldComponentPoolsCacheSize];
            _filterCtor = new Object[] { this };
        }

        /// <summary>
        /// Component pools cache.
        /// </summary>
        public IEcsComponentPool[] ComponentPools;

        protected bool IsDestroyed;
#if !ECS_DISABLE_DEBUG_CHECKS
        internal readonly List<IEcsWorldDebugListener> DebugListeners = new List<IEcsWorldDebugListener> (4);
        readonly EcsGrowList<EcsEntity> _leakedEntities = new EcsGrowList<EcsEntity> (256);
        bool _inDestroying;

        /// <summary>
        /// Adds external event listener.
        /// </summary>
        /// <param name="listener">Event listener.</param>
        public void AddDebugListener (IEcsWorldDebugListener listener)
		{
            /*if (listener == null) { throw new Exception ("Listener is null."); }*/
			Runtime.Assert(listener != null, "Listener is null");
            DebugListeners.Add (listener);
        }

        /// <summary>
        /// Removes external event listener.
        /// </summary>
        /// <param name="listener">Event listener.</param>
        public void RemoveDebugListener (IEcsWorldDebugListener listener)
		{
            /*if (listener == null) { throw new Exception ("Listener is null."); }*/
			Runtime.Assert(listener != null, "Listener is null");
            DebugListeners.Remove (listener);
        }
#endif

        /// <summary>
        /// Destroys world and exist entities.
        /// </summary>
        public virtual void Destroy ()
		{
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (IsDestroyed || _inDestroying) { throw new Exception ("EcsWorld already destroyed."); }*/
			Runtime.Assert(!IsDestroyed && !_inDestroying, "EcsWorld already destroyed.");

            _inDestroying = true;
            CheckForLeakedEntities ("Destroy");
#endif
            EcsEntity entity;
            entity.Owner = this;
            for (var i = EntitiesCount - 1; i >= 0; i--)
			{
                ref Self.EcsEntityData entityData = ref Entities[i];
                if (entityData.ComponentsCountX2 > 0) {
                    entity.Id = i;
                    entity.Gen = entityData.Gen;
                    entity.Destroy ();
                }
            }
            for (int i = 0, int iMax = Filters.Count; i < iMax; i++) {
                Filters.Items[i].Destroy ();
            }

            IsDestroyed = true;
#if !ECS_DISABLE_DEBUG_CHECKS
            for (var i = DebugListeners.Count - 1; i >= 0; i--)
			{
                DebugListeners[i].OnWorldDestroyed (this);
            }
#endif
        }

        /// <summary>
        /// Is world not destroyed.
        /// </summary>
        /*[MethodImpl (MethodImplOptions.AggressiveInlining)]*/
		[Inline]
        public bool IsAlive ()
		{
            return !IsDestroyed;
        }

        /// <summary>
        /// Creates new entity.
        /// </summary>
        /*[MethodImpl (MethodImplOptions.AggressiveInlining)]*/
		[Inline]
        public EcsEntity NewEntity ()
		{
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (IsDestroyed) { throw new Exception ("EcsWorld already destroyed."); }*/
			Runtime.Assert(!IsDestroyed, "EcsWorld already destroyed.");
#endif
            EcsEntity entity;
            entity.Owner = this;
            // try to reuse entity from pool.
            if (FreeEntities.Count > 0)
			{
                entity.Id = FreeEntities.Items[--FreeEntities.Count];
                ref Self.EcsEntityData entityData = ref Entities[entity.Id];
                entity.Gen = entityData.Gen;
                entityData.ComponentsCountX2 = 0;
            }
			else
			{
                // create new entity.
                if (EntitiesCount == Entities.Count) {
                    Util.ResizeArray (ref Entities, EntitiesCount << 1);
                }
                entity.Id = EntitiesCount++;
                ref Self.EcsEntityData entityData = ref Entities[entity.Id];
                entityData.Components = new int[Config.EntityComponentsCacheSize * 2];
                entityData.Gen = 1;
                entity.Gen = entityData.Gen;
                entityData.ComponentsCountX2 = 0;
            }
#if !ECS_DISABLE_DEBUG_CHECKS
            _leakedEntities.Add (entity);
            for (var debugListener in DebugListeners)
			{
                debugListener.OnEntityCreated (entity);
            }
#endif
            return entity;
        }

        /// <summary>
        /// Restores EcsEntity from internal id and gen. For internal use only!
        /// </summary>
        /// <param name="id">Internal id.</param>
        /// <param name="gen">Generation. If less than 0 - will be filled from current generation value.</param>
        [Inline]
        public EcsEntity RestoreEntityFromInternalId (int id, int gen = -1)
		{
            EcsEntity entity;
            entity.Owner = this;
            entity.Id = id;
            if (gen < 0)
			{
                entity.Gen = 0;
                ref Self.EcsEntityData entityData = ref GetEntityData (entity);
                entity.Gen = entityData.Gen;
            }
			else
			{
                entity.Gen = (uint16) gen;
            }
            return entity;
        }

        /// <summary>
        /// Request exist filter or create new one. For internal use only!
        /// </summary>
        /// <param name="filterType">Filter type.</param>
        /// <param name="createIfNotExists">Create filter if not exists.</param>
        public EcsFilter GetFilter (Type filterType, bool createIfNotExists = true)
		{
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (filterType == null) { throw new Exception ("FilterType is null."); }*/
			Runtime.Assert(filterType != null,"FilterType is null.");

            /*if (!filterType.IsSubclassOf (typeof (EcsFilter)))
				{ throw new Exception ($"Invalid filter type: {filterType}."); }*/
			Runtime.Assert(filterType.IsSubclassOf (typeof (EcsFilter)), scope $"Invalid filter type: {filterType}.");

            /*if (IsDestroyed) { throw new Exception ("EcsWorld already destroyed."); }*/
			Runtime.Assert(!IsDestroyed,"EcsWorld already destroyed.");
#endif
            // check already exist filters.
            for (int i = 0, int iMax = Filters.Count; i < iMax; i++)
			{
                if (Filters.Items[i].GetType () == filterType)
				{
                    return Filters.Items[i];
                }
            }
            if (!createIfNotExists)
			{
                return null;
            }
            // create new filter.
            var filter = (EcsFilter) Activator.CreateInstance (filterType, BindingFlags.NonPublic | BindingFlags.Instance, null, _filterCtor, CultureInfo.InvariantCulture);
#if !ECS_DISABLE_DEBUG_CHECKS
            for (var filterIdx = 0; filterIdx < Filters.Count; filterIdx++)
			{
                /*if (filter.AreComponentsSame (Filters.Items[filterIdx])) {
                    throw new Exception (
                        $"Invalid filter \"{filter.GetType ()}\": Another filter \"{Filters.Items[filterIdx].GetType ()}\" already has same components, but in different order.");
                }*/
				// TODO: Multi-Line String Solution
				Runtime.Assert(!filter.AreComponentsSame (Filters.Items[filterIdx]),
					scope $"Invalid filter \"{filter.GetType()}\": Another filter \"{Filters.Items[filterIdx].GetType()}\" already has same components, but in different order.");
            }
#endif
            Filters.Add (filter);
            // add to component dictionaries for fast compatibility scan.
            for (int i = 0, int iMax = filter.IncludedTypeIndices.Count; i < iMax; i++)
			{
				EcsGrowList<EcsFilter> filtersList;
                if (!FilterByIncludedComponents.TryGetValue (filter.IncludedTypeIndices[i], out filtersList))
				{
                    filtersList = new EcsGrowList<EcsFilter> (8);
                    FilterByIncludedComponents[filter.IncludedTypeIndices[i]] = filtersList;
                }
                filtersList.Add (filter);
            }
            if (filter.ExcludedTypeIndices != null)
			{
                for (int i = 0, int iMax = filter.ExcludedTypeIndices.Count; i < iMax; i++)
				{
					EcsGrowList<EcsFilter> filtersList;
                    if (!FilterByExcludedComponents.TryGetValue (filter.ExcludedTypeIndices[i], out filtersList))
					{
                        filtersList = new EcsGrowList<EcsFilter> (8);
                        FilterByExcludedComponents[filter.ExcludedTypeIndices[i]] = filtersList;
                    }
                    filtersList.Add (filter);
                }
            }
#if !ECS_DISABLE_DEBUG_CHECKS
            for (var debugListener in DebugListeners)
			{
                debugListener.OnFilterCreated (filter);
            }
#endif
            // scan exist entities for compatibility with new filter.
            EcsEntity entity;
            entity.Owner = this;
            for (int i = 0, int iMax = EntitiesCount; i < iMax; i++)
			{
                ref Self.EcsEntityData entityData = ref Entities[i];
                if (entityData.ComponentsCountX2 > 0 && filter.IsCompatible (entityData, 0))
				{
                    entity.Id = i;
                    entity.Gen = entityData.Gen;
                    filter.OnAddEntity (entity);
                }
            }
            return filter;
        }

        /// <summary>
        /// Gets stats of internal data.
        /// </summary>
        public EcsWorldStats GetStats ()
		{
            let stats = EcsWorldStats () {
                ActiveEntities = EntitiesCount - FreeEntities.Count,
                ReservedEntities = FreeEntities.Count,
                Filters = Filters.Count,
                Components = _usedComponentsCount
            };
            return stats;
        }

        /// <summary>
        /// Recycles internal entity data to pool.
        /// </summary>
        /// <param name="id">Entity id.</param>
        /// <param name="entityData">Entity internal data.</param>
        protected internal void RecycleEntityData (int id, ref EcsEntityData entityData)
		{
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (entityData.ComponentsCountX2 != 0) { throw new Exception ("Cant recycle invalid entity."); }*/
			Runtime.Assert(entityData.ComponentsCountX2 == 0, "Cant recycle invalid entity.");
#endif
            entityData.ComponentsCountX2 = -2;
            entityData.Gen++;
            if (entityData.Gen == 0) { entityData.Gen = 1; }
            FreeEntities.Add (id);
        }

#if !ECS_DISABLE_DEBUG_CHECKS
        /// <summary>
        /// Checks exist entities but without components.
        /// </summary>
        /// <param name="errorMsg">Prefix for error message.</param>
        public bool CheckForLeakedEntities (String errorMsg)
		{
            if (_leakedEntities.Count > 0)
			{
                for (int i = 0, int iMax = _leakedEntities.Count; i < iMax; i++)
				{
                    if (GetEntityData (_leakedEntities.Items[i]).ComponentsCountX2 == 0)
					{
                        /*if (errorMsg != null) {
                            throw new Exception ($"{errorMsg}: Empty entity detected, possible memory leak.");
                        }*/
						Runtime.Assert(errorMsg == null, "{}: Empty entity detected, possible memory leak.", errorMsg);
                        return true;
                    }
                }
                _leakedEntities.Count = 0;
            }
            return false;
        }
#endif

        /// <summary>
        /// Updates filters.
        /// </summary>
        /// <param name="typeIdx">Component type index.abstract Positive for add operation, negative for remove operation.</param>
        /// <param name="entity">Target entity.</param>
        /// <param name="entityData">Target entity data.</param>
        /*[MethodImpl (MethodImplOptions.AggressiveInlining)]*/
		[Inline]
        protected internal void UpdateFilters (int typeIdx, in EcsEntity entity, in EcsEntityData entityData)
		{
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (IsDestroyed) { throw new Exception ("EcsWorld already destroyed."); }*/
			Runtime.Assert(!IsDestroyed, "EcsWorld already destroyed.");
#endif
            EcsGrowList<EcsFilter> filters;
            if (typeIdx < 0)
			{
                // remove component.
                if (FilterByIncludedComponents.TryGetValue (-typeIdx, out filters))
				{
                    for (int i = 0, int iMax = filters.Count; i < iMax; i++)
					{
                        if (filters.Items[i].IsCompatible (entityData, 0))
						{
#if !ECS_DISABLE_DEBUG_CHECKS
							int filterIdx;
                            if (!filters.Items[i].GetInternalEntitiesMap ().TryGetValue (entity.GetInternalId (), out filterIdx))
							{
								filterIdx = -1;
							}
                            /*if (filterIdx < 0) { throw new Exception ("Entity not in filter."); }*/
							Runtime.Assert(filterIdx >= 0, "Entity not in filter.");
#endif
                            filters.Items[i].OnRemoveEntity (entity);
                        }
                    }
                }
                if (FilterByExcludedComponents.TryGetValue (-typeIdx, out filters))
				{
                    for (int i = 0, int iMax = filters.Count; i < iMax; i++)
					{
                        if (filters.Items[i].IsCompatible (entityData, typeIdx))
						{
#if !ECS_DISABLE_DEBUG_CHECKS
							int filterIdx;
                            if (!filters.Items[i].GetInternalEntitiesMap ().TryGetValue (entity.GetInternalId (), out filterIdx))
							{
								filterIdx = -1;
							}
                            /*if (filterIdx >= 0) { throw new Exception ("Entity already in filter."); }*/
							Runtime.Assert(filterIdx < 0, "Entity already in filter.");
#endif
                            filters.Items[i].OnAddEntity (entity);
                        }
                    }
                }
            }
			else
			{
                // add component.
                if (FilterByIncludedComponents.TryGetValue (typeIdx, out filters)) {
                    for (int i = 0, int iMax = filters.Count; i < iMax; i++) {
                        if (filters.Items[i].IsCompatible (entityData, 0)) {
#if !ECS_DISABLE_DEBUG_CHECKS
							int filterIdx;
                            if (!filters.Items[i].GetInternalEntitiesMap ().TryGetValue (entity.GetInternalId (), out filterIdx)) { filterIdx = -1; }
                            /*if (filterIdx >= 0) { throw new Exception ("Entity already in filter."); }*/
							Runtime.Assert(filterIdx < 0, "Entity already in filter.");
#endif
                            filters.Items[i].OnAddEntity (entity);
                        }
                    }
                }
                if (FilterByExcludedComponents.TryGetValue (typeIdx, out filters)) {
                    for (int i = 0, int iMax = filters.Count; i < iMax; i++) {
                        if (filters.Items[i].IsCompatible (entityData, -typeIdx)) {
#if !ECS_DISABLE_DEBUG_CHECKS
							int filterIdx;
                            if (!filters.Items[i].GetInternalEntitiesMap ().TryGetValue (entity.GetInternalId (), out filterIdx)) { filterIdx = -1; }
                            /*if (filterIdx < 0) { throw new Exception ("Entity not in filter."); }*/
							Runtime.Assert(filterIdx >= 0, "Entity not in filter.");
#endif
                            filters.Items[i].OnRemoveEntity (entity);
                        }
                    }
                }
            }
        }

        /// <summary>
        /// Returns internal state of entity. For internal use!
        /// </summary>
        /// <param name="entity">Entity.</param>
        /*[MethodImpl (MethodImplOptions.AggressiveInlining)]*/
		[Inline]
        public ref EcsEntityData GetEntityData (in EcsEntity entity)
		{
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (IsDestroyed) { throw new Exception ("EcsWorld already destroyed."); }*/
			Runtime.Assert(!IsDestroyed, "EcsWorld already destroyed.");
            /*if (entity.Id < 0 || entity.Id > EntitiesCount) { throw new Exception ("Invalid entity {}", entity.Id); }*/
			Runtime.Assert(!(entity.Id < 0 || entity.Id > EntitiesCount), scope $"Invalid entity {entity.Id}");
#endif
            return ref Entities[entity.Id];
        }

        /// <summary>
        /// Internal state of entity.
        /// </summary>
        [StructLayout (LayoutKind.Sequential, Pack = 2)] // TODO: Translate This
        public struct EcsEntityData
		{
            public uint16 Gen;
            public int16 ComponentsCountX2;
            public int[] Components;
        }

        /*[MethodImpl (MethodImplOptions.AggressiveInlining)]*/
		[Inline]
        public EcsComponentPool<T> GetPool<T> () where T : struct
		{
            var typeIdx = EcsComponentType<T>.TypeIndex;
            if (ComponentPools.Count < typeIdx) {
                var len = ComponentPools.Count << 1;
                while (len <= typeIdx) {
                    len <<= 1;
                }
                Util.ResizeArray (ref ComponentPools, len);
            }
            var pool = (EcsComponentPool<T>) ComponentPools[typeIdx];
            if (pool == null) {
                pool = new EcsComponentPool<T> ();
                ComponentPools[typeIdx] = pool;
                _usedComponentsCount++;
            }
            return pool;
        }

        /// <summary>
        /// Gets all alive entities.
        /// </summary>
        /// <param name="entities">List to put results in it. if null - will be created. If not enough space - will be resized.</param>
        /// <returns>Amount of alive entities.</returns>
        public int GetAllEntities (ref EcsEntity[] entities)
		{
            var count = EntitiesCount - FreeEntities.Count;
            if (entities == null || entities.Count < count)
			{
                entities = new EcsEntity[count];
            }
            EcsEntity e;
            e.Owner = this;
            var id = 0;
            for (int i = 0, int iMax = EntitiesCount; i < iMax; i++)
			{
                ref Self.EcsEntityData entityData = ref Entities[i];
                // should we skip empty entities here?
                if (entityData.ComponentsCountX2 >= 0)
				{
                    e.Id = i;
                    e.Gen = entityData.Gen;
                    entities[id++] = e;
                }
            }
            return count;
        }
		

		public int GetHashCode()
		{
			return 0; // TODO: Hash an Instance of World (static int for instance count?)
		}
    }

    /// <summary>
    /// Stats of EcsWorld instance.
    /// </summary>
    public struct EcsWorldStats
	{
        /// <summary>
        /// Amount of active entities.
        /// </summary>
        public int ActiveEntities;

        /// <summary>
        /// Amount of cached (not in use) entities.
        /// </summary>
        public int ReservedEntities;

        /// <summary>
        /// Amount of registered filters.
        /// </summary>
        public int Filters;

        /// <summary>
        /// Amount of registered component types.
        /// </summary>
        public int Components;
    }

    /// <summary>
    /// World config to setup default caches.
    /// </summary>
    public struct EcsWorldConfig
	{
        /// <summary>
        /// World.Entities cache size.
        /// </summary>
        public int32 WorldEntitiesCacheSize;
        /// <summary>
        /// World.Filters cache size.
        /// </summary>
        public int32 WorldFiltersCacheSize;
        /// <summary>
        /// World.ComponentPools cache size.
        /// </summary>
        public int32 WorldComponentPoolsCacheSize;
        /// <summary>
        /// Entity.Components cache size (not doubled).
        /// </summary>
        public int32 EntityComponentsCacheSize;
        /// <summary>
        /// Filter.Entities cache size.
        /// </summary>
        public int32 FilterEntitiesCacheSize;
        /// <summary>
        /// World.Entities default cache size.
        /// </summary>
        public const int32 DefaultWorldEntitiesCacheSize = 1024;
        /// <summary>
        /// World.Filters default cache size.
        /// </summary>
        public const int32 DefaultWorldFiltersCacheSize = 128;
        /// <summary>
        /// World.ComponentPools default cache size.
        /// </summary>
        public const int32 DefaultWorldComponentPoolsCacheSize = 512;
        /// <summary>
        /// Entity.Components default cache size (not doubled).
        /// </summary>
        public const int32 DefaultEntityComponentsCacheSize = 8;
        /// <summary>
        /// Filter.Entities default cache size.
        /// </summary>
        public const int32 DefaultFilterEntitiesCacheSize = 256;
    }

#if !ECS_DISABLE_DEBUG_CHECKS
    /// <summary>
    /// Debug interface for world events processing.
    /// </summary>
    public interface IEcsWorldDebugListener
	{
        void OnEntityCreated (EcsEntity entity);
        void OnEntityDestroyed (EcsEntity entity);
        void OnFilterCreated (EcsFilter filter);
        void OnComponentListChanged (EcsEntity entity);
        void OnWorldDestroyed (EcsWorld world);
    }
#endif
}