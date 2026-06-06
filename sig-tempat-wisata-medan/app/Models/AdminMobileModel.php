<?php

namespace App\Models;

use CodeIgniter\Model;

class AdminMobileModel extends Model
{
    protected $table = 'admin_mobile';
    protected $primaryKey = 'id';
    protected $returnType = 'array';
    protected $allowedFields = ['username', 'no_pegawai', 'foto_profil', 'created_at'];
}
