// ----------------------------------------------------------------------------
// The MIT License
// Simple Entity Component System framework https://github.com/Leopotam/ecs
// Copyright (c) 2017-2021 Leopotam <leopotam@gmail.com>
// ----------------------------------------------------------------------------

using System;

using System.Threading;

using internal Leopotam.Ecs;
// ReSharper disable ClassNeverInstantiated.Global

namespace Leopotam.Ecs
{
    /// <summary>
    /// Marks component type to be not auto-filled as GetX in filter.
    /// </summary>
    public interface IEcsIgnoreInFilter { }

    /// <summary>
    /// Marks component type for custom reset behaviour.
    /// </summary>
    /// <typeparam name="T">Type of component, should be the same as main component!</typeparam>
    public interface IEcsAutoReset<T> where T : struct
	{
        void AutoReset (ref T c);
    }

    /// <summary>
    /// Marks field of IEcsSystem class to be ignored during dependency injection.
    /// </summary>
    public sealed struct EcsIgnoreInjectAttribute : Attribute { }

    /// <summary>
    /// Global descriptor of used component type.
    /// </summary>
    /// <typeparam name="T">Component type.</typeparam>
    public static class EcsComponentType<T> where T : struct
	{
        // ReSharper disable StaticMemberInGenericType
        public static readonly int TypeIndex;
        public static readonly Type Type;
        public static readonly bool IsIgnoreInFilter;
        public static readonly bool IsAutoReset;
        // ReSharper restore StaticMemberInGenericType

        static this()
		{
            TypeIndex = Interlocked.Increment (ref EcsComponentPool.ComponentTypesCount);
            Type = typeof (T);
            IsIgnoreInFilter = typeof (IEcsIgnoreInFilter).IsAssignableFrom (Type);

            IsAutoReset = typeof (IEcsAutoReset<T>).IsAssignableFrom (Type);
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (!IsAutoReset && Type.GetInterface ("IEcsAutoReset`1") != null) {
                throw new Exception ($"IEcsAutoReset should have <{typeof (T).Name}> constraint for component \"{typeof (T).Name}\".");
            }*/
			Runtime.Assert(
				!(!IsAutoReset && Type.GetInterface ("IEcsAutoReset`1") != null),
				scope $"IEcsAutoReset should have <{typeof(T)}> constraint for component \"{typeof(T)}\".");
#endif
        }
    }

    public sealed class EcsComponentPool
	{
        /// <summary>
        /// Global component type counter.
        /// First component will be "1" for correct filters updating (add component on positive and remove on negative).
        /// </summary>
        internal static int ComponentTypesCount;
    }

    public interface IEcsComponentPool
	{
        Type ItemType { get; }
        Object GetItem (int idx);
        void Recycle (int idx);
        int New ();
        void CopyData (int srcIdx, int dstIdx);
    }

    /// <summary>
    /// Helper for save reference to component. 
    /// </summary>
    /// <typeparam name="T">Type of component.</typeparam>
    public struct EcsComponentRef<T> where T : struct
	{
        internal EcsComponentPool<T> Pool;
        internal int Idx;
        
        [Inline]
        public static bool AreEquals (in EcsComponentRef<T> lhs, in EcsComponentRef<T> rhs) {
            return lhs.Idx == rhs.Idx && lhs.Pool == rhs.Pool;
        }
    }

    public extension EcsComponentRef<T> where T : struct 
	{
        [Inline]
        public ref T Unref ()
		{
            return ref Pool.Items[Idx];
        }

        [Inline]
        public bool IsNull ()
		{
            return Pool == null;
        }
    }

    public interface IEcsComponentPoolResizeListener
	{
        void OnComponentPoolResize ();
    }

    public sealed class EcsComponentPool<T> : IEcsComponentPool where T : struct
	{
        delegate void AutoResetHandler (ref T component);

        public Type ItemType { get; }
        public T[] Items = new T[128];
        int[] _reservedItems = new int[128];
        int _itemsCount;
        int _reservedItemsCount;
        readonly AutoResetHandler _autoReset;

        IEcsComponentPoolResizeListener[] _resizeListeners;
        int _resizeListenersCount;

        internal this ()
		{
            ItemType = typeof (T);
            if (EcsComponentType<T>.IsAutoReset)
			{
                var autoResetMethod = typeof (T).GetMethod (nameof (IEcsAutoReset<T>.AutoReset));
#if !ECS_DISABLE_DEBUG_CHECKS
                /*if (autoResetMethod == null) {
                    throw new Exception (
                        $"IEcsAutoReset<{typeof(T)}> explicit implementation not supported, use implicit instead.");
                }*/
				Runtime.Assert(autoResetMethod == .Ok, scope $"IEcsAutoReset<{typeof(T)}> explicit implementation not supported, use implicit instead.");
#endif
                _autoReset = (AutoResetHandler) Delegate.CreateDelegate (
                    typeof (AutoResetHandler),
                    null,
                    autoResetMethod);
            }
            _resizeListeners = new IEcsComponentPoolResizeListener[128];
            _reservedItemsCount = 0;
        }

        void RaiseOnResizeEvent ()
		{
            for (int i = 0, int iMax = _resizeListenersCount; i < iMax; i++)
			{
                _resizeListeners[i].OnComponentPoolResize ();
            }
        }

        public void AddResizeListener (IEcsComponentPoolResizeListener listener)
		{
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (listener == null) { throw new Exception ("Listener is null."); }*/
			Runtime.Assert(listener != null, "Listener is null.");
#endif
            if (_resizeListeners.Count == _resizeListenersCount)
			{
                Util.ResizeArray (ref _resizeListeners, _resizeListenersCount << 1);
            }
            _resizeListeners[_resizeListenersCount++] = listener;
        }

        public void RemoveResizeListener (IEcsComponentPoolResizeListener listener)
		{
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (listener == null) { throw new Exception ("Listener is null."); }*/
			Runtime.Assert(listener != null, "Listener is null.");
#endif
            for (int i = 0, int iMax = _resizeListenersCount; i < iMax; i++)
			{
                if (_resizeListeners[i] == listener)
				{
                    _resizeListenersCount--;
                    if (i < _resizeListenersCount)
					{
                        _resizeListeners[i] = _resizeListeners[_resizeListenersCount];
                    }
                    _resizeListeners[_resizeListenersCount] = null;
                    break;
                }
            }
        }

        /// <summary>
        /// Sets new capacity (if more than current amount).
        /// </summary>
        /// <param name="capacity">New value.</param>
        public void SetCapacity (int capacity)
		{
            if (capacity > Items.Count)
			{
                Util.ResizeArray (ref Items, capacity);
                RaiseOnResizeEvent ();
            }
        }

        [Inline]
        public int New ()
		{
            int id;
            if (_reservedItemsCount > 0)
			{
                id = _reservedItems[--_reservedItemsCount];
            }
			else
			{
                id = _itemsCount;
                if (_itemsCount == Items.Count)
				{
                    Util.ResizeArray (ref Items, _itemsCount << 1);
                    RaiseOnResizeEvent ();
                }
                // reset brand new instance if custom AutoReset was registered.
                _autoReset?.Invoke (ref Items[_itemsCount]);
                _itemsCount++;
            }
            return id;
        }

        [Inline]
        public ref T GetItem (int idx)
		{
            return ref Items[idx];
        }

        [Inline]
        public void Recycle (int idx)
		{
            if (_autoReset != null)
			{
                _autoReset (ref Items[idx]);
            }
			else
			{
                Items[idx] = default;
            }
            if (_reservedItemsCount == _reservedItems.Count)
			{
                Util.ResizeArray (ref _reservedItems, _reservedItemsCount << 1);
            }
            _reservedItems[_reservedItemsCount++] = idx;
        }

        [Inline]
        public void CopyData (int srcIdx, int dstIdx)
		{
            Items[dstIdx] = Items[srcIdx];
        }

        [Inline]
        public EcsComponentRef<T> Ref (int idx)
		{
            EcsComponentRef<T> componentRef;
            componentRef.Pool = this;
            componentRef.Idx = idx;
            return componentRef;
        }

        Object IEcsComponentPool.GetItem (int idx)
		{
            return Items[idx];
        }
    }
}