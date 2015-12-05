module priority_queue;

import std.container.array;

class PriorityQueue(T,P) {
private:
    struct Elem {
        T data;
        P priority;
    };
    int     num;
    int     allocated;
    Array!Elem  buffer;

    void resize(int newalloc) {
        buffer.reserve(newalloc);
        buffer.length = newalloc;
        allocated = newalloc;
    }
    int find(T data) const {
        for (int i=1; i<num; ++i)
            if (buffer[i].data == data)
                return i;
        return 0;
    }
    int bubble_down(int n, P priority) {
        int m;
        while ((m=n*2)<num) {
            if ((m+1 < num) && (buffer[m].priority > buffer[m+1].priority))
                ++m;
            if (priority <= buffer[m].priority)
                break;
            buffer[n] = buffer[m];
            n = m;
        }
        return n;
    }
    int bubble_up(int n, P priority) {
        int m;
        /* append at end, then up heap */
        while (((m=n/2) != 0) && (priority < buffer[m].priority)) {
            buffer[n] = buffer[m];
            n = m;
        }
        return n;
    }
public:
    this(int size=4) {
        if (size<4) size = 4;
        buffer.reserve(size);
        allocated = size;
        buffer.length = size;
        num = 1;
    }
    void purge() {
        num = 1;
    }
    int size() const {
        return num - 1;
    }
    bool is_in(T data) const {
        return (find(data) != 0);
    }
    bool change_priority(T data, P priority) {
        if (!remove(data))
            return false;
        push(data, priority);
        return true;
    }
    bool remove(T data) {
        int i = find(data);
        if (!i) return false;
        --num;
        int n = bubble_down(i, buffer[num].priority);
        buffer[n] = buffer[num];
        return true;
    }
    void push(T data, P priority) {
        if (num >= allocated)
            resize(allocated*2);
        /* append at end, then up heap */
        int n = bubble_up(num++, priority);
        buffer[n].data = data;
        buffer[n].priority = priority;
    }
    P top_priority() const {
        return buffer[(num == 1) ? 0 : 1].priority;
    }
    T top() const {
        P priority;
        return top(priority);
    }
    T top(ref P priority) const {
        if (num == 1) {
            priority = buffer[0].priority;
            return cast(T)buffer[0].data;
        } else {
            priority = buffer[1].priority;
            return cast(T)buffer[1].data;
        }
    }
    T pop() {
        P priority;
        return pop(priority);
    }
    T pop(ref P priority) {
        if (num==1) return buffer[0].data;
        T out_data = buffer[1].data;
        priority = buffer[1].priority;
        /* pull last item to top, then down heap */
        --num;
        int n = bubble_down(1, buffer[num].priority);
        buffer[n] = buffer[num];
        return out_data;
    }

    public int opApply(int delegate(ref T) dg) {
        foreach (e; buffer[1..num])
            if (int res = dg(e.data))
                return res;
        return 0;
    }

    public int opApply(int delegate(const ref T) dg) const {
        foreach (e; buffer[1..num])
            if (int res = dg(e.data))
                return res;
        return 0;
    }

    public int opApply(int delegate(ref T, const ref P) dg) {
        foreach (e; buffer[1..num])
            if (int res = dg(e.data, e.priority))
                return res;
        return 0;
    }

    public int opApply(int delegate(const ref T, const ref P) dg) const {
        foreach (e; buffer[1..num])
            if (int res = dg(e.data, e.priority))
                return res;
        return 0;
    }
}
