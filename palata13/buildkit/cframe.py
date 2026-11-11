"""Minimal CFrame / Vector3 math mirroring Roblox semantics (row-major 3x3 rotation)."""
import math


class V3(tuple):
    __slots__ = ()

    def __new__(cls, x=0.0, y=0.0, z=0.0):
        return tuple.__new__(cls, (float(x), float(y), float(z)))

    x = property(lambda s: s[0])
    y = property(lambda s: s[1])
    z = property(lambda s: s[2])

    def __add__(self, o):
        return V3(self[0] + o[0], self[1] + o[1], self[2] + o[2])

    def __sub__(self, o):
        return V3(self[0] - o[0], self[1] - o[1], self[2] - o[2])

    def __mul__(self, k):
        return V3(self[0] * k, self[1] * k, self[2] * k)

    __rmul__ = __mul__

    def __neg__(self):
        return V3(-self[0], -self[1], -self[2])

    def dot(self, o):
        return self[0] * o[0] + self[1] * o[1] + self[2] * o[2]

    def cross(self, o):
        return V3(self[1] * o[2] - self[2] * o[1], self[2] * o[0] - self[0] * o[2], self[0] * o[1] - self[1] * o[0])

    @property
    def mag(self):
        return math.sqrt(self.dot(self))

    @property
    def unit(self):
        m = self.mag
        return V3(0, 0, 0) if m < 1e-9 else self * (1.0 / m)

    def lerp(self, o, t):
        return self + (o - self) * t


IDENT = (1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)


class CF:
    """Position + rotation. Matrix is row-major: R00 R01 R02 / R10 R11 R12 / R20 R21 R22.
    Columns are RightVector, UpVector, -LookVector (Roblox convention)."""
    __slots__ = ("p", "r")

    def __init__(self, p=(0.0, 0.0, 0.0), r=IDENT):
        self.p = V3(*p)
        self.r = tuple(float(v) for v in r)

    @staticmethod
    def new(x=0.0, y=0.0, z=0.0):
        return CF((x, y, z))

    @staticmethod
    def angles(rx=0.0, ry=0.0, rz=0.0):
        # Roblox CFrame.Angles == fromEulerAnglesXYZ == Rx * Ry * Rz
        return CF.rot_x(rx) * CF.rot_y(ry) * CF.rot_z(rz)

    @staticmethod
    def rot_x(a):
        c, s = math.cos(a), math.sin(a)
        return CF((0, 0, 0), (1, 0, 0, 0, c, -s, 0, s, c))

    @staticmethod
    def rot_y(a):
        c, s = math.cos(a), math.sin(a)
        return CF((0, 0, 0), (c, 0, s, 0, 1, 0, -s, 0, c))

    @staticmethod
    def rot_z(a):
        c, s = math.cos(a), math.sin(a)
        return CF((0, 0, 0), (c, -s, 0, s, c, 0, 0, 0, 1))

    @staticmethod
    def lookat(pos, target, up=(0, 1, 0)):
        pos, target = V3(*pos), V3(*target)
        look = (target - pos).unit
        if look.mag < 1e-9:
            return CF(pos)
        upv = V3(*up)
        if abs(look.dot(upv)) > 0.999:
            upv = V3(0, 0, 1) if abs(look.y) > 0.9 else V3(0, 1, 0)
        right = look.cross(upv).unit
        u = right.cross(look).unit
        back = -look
        return CF(pos, (right.x, u.x, back.x, right.y, u.y, back.y, right.z, u.z, back.z))

    @staticmethod
    def from_axis(axis, angle):
        a = V3(*axis).unit
        c, s = math.cos(angle), math.sin(angle)
        t = 1 - c
        x, y, z = a
        return CF((0, 0, 0), (
            t * x * x + c, t * x * y - s * z, t * x * z + s * y,
            t * x * y + s * z, t * y * y + c, t * y * z - s * x,
            t * x * z - s * y, t * y * z + s * x, t * z * z + c))

    def __mul__(self, o):
        r = self.r
        if isinstance(o, CF):
            q = o.r
            nr = (
                r[0] * q[0] + r[1] * q[3] + r[2] * q[6], r[0] * q[1] + r[1] * q[4] + r[2] * q[7], r[0] * q[2] + r[1] * q[5] + r[2] * q[8],
                r[3] * q[0] + r[4] * q[3] + r[5] * q[6], r[3] * q[1] + r[4] * q[4] + r[5] * q[7], r[3] * q[2] + r[4] * q[5] + r[5] * q[8],
                r[6] * q[0] + r[7] * q[3] + r[8] * q[6], r[6] * q[1] + r[7] * q[4] + r[8] * q[7], r[6] * q[2] + r[7] * q[5] + r[8] * q[8],
            )
            return CF(self.point(o.p), nr)
        return self.point(o)

    def point(self, v):
        r = self.r
        return V3(
            r[0] * v[0] + r[1] * v[1] + r[2] * v[2] + self.p[0],
            r[3] * v[0] + r[4] * v[1] + r[5] * v[2] + self.p[1],
            r[6] * v[0] + r[7] * v[1] + r[8] * v[2] + self.p[2])

    def vector(self, v):
        r = self.r
        return V3(r[0] * v[0] + r[1] * v[1] + r[2] * v[2], r[3] * v[0] + r[4] * v[1] + r[5] * v[2], r[6] * v[0] + r[7] * v[1] + r[8] * v[2])

    def inverse(self):
        r = self.r
        t = (r[0], r[3], r[6], r[1], r[4], r[7], r[2], r[5], r[8])
        inv = CF((0, 0, 0), t)
        return CF(-inv.vector(self.p), t)

    def to_object_space(self, other):
        return self.inverse() * other

    @property
    def right(self):
        return V3(self.r[0], self.r[3], self.r[6])

    @property
    def up(self):
        return V3(self.r[1], self.r[4], self.r[7])

    @property
    def look(self):
        return V3(-self.r[2], -self.r[5], -self.r[8])

    def offset(self, x=0.0, y=0.0, z=0.0):
        return self * CF.new(x, y, z)

    def with_pos(self, p):
        return CF(p, self.r)

    def __repr__(self):
        return "CF(p=%s)" % (tuple(round(v, 2) for v in self.p),)


def deg(d):
    return math.radians(d)
